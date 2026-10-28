#!/usr/bin/env python3
"""BuildLight 后台监视器。

GitHub 没有「跨仓库」的 Actions 事件流，只能按仓库轮询。
为了省配额：每个仓库用 ETag 条件请求，304 不计数。

只做三件事：
1. 构建失败 / 取消 —— 立刻推，带失败的 step 名
2. 产物就绪 —— 成功且有 artifact 才推（普通成功不吵人）
3. 异常 —— 排队超过阈值、耗时比历史中位数暴涨
"""
import json
import os
import sqlite3
import statistics
import sys
import time
import urllib.error
import urllib.parse
import urllib.request
from datetime import datetime, timedelta, timezone

API = "https://api.github.com"
TOKEN = os.environ["GITHUB_TOKEN"]
BARK_KEY = os.environ["BARK_KEY"]
STATE_DB = os.environ.get("STATE_DB", "/var/lib/buildlight-watch/state.db")
CONFIG_PATH = os.environ.get("CONFIG_PATH", "/etc/buildlight-watch.json")
CST = timezone(timedelta(hours=8))

DEFAULTS = {
    "poll_seconds": 60,
    "queue_alert_seconds": 180,
    "regression_ratio": 1.3,
    "regression_min_seconds": 60,
    "repos": "auto",
    "include": [],
    "exclude": [],
    "quiet_hours": [],
}


def log(msg):
    stamp = datetime.now(CST).strftime("%m-%d %H:%M:%S")
    print(f"[{stamp}] {msg}", flush=True)


def load_config():
    cfg = dict(DEFAULTS)
    try:
        with open(CONFIG_PATH) as f:
            cfg.update(json.load(f))
    except FileNotFoundError:
        pass
    return cfg


# ---------------------------------------------------------------- http

def api(path, etag=None, raw_url=None):
    """返回 (status, payload, etag)。304 时 payload 为 None。"""
    url = raw_url or (API + path)
    req = urllib.request.Request(url)
    req.add_header("Authorization", f"Bearer {TOKEN}")
    req.add_header("Accept", "application/vnd.github+json")
    req.add_header("X-GitHub-Api-Version", "2022-11-28")
    req.add_header("User-Agent", "buildlight-watch/1.0")
    if etag:
        req.add_header("If-None-Match", etag)
    try:
        with urllib.request.urlopen(req, timeout=25) as resp:
            body = resp.read()
            return resp.status, json.loads(body) if body else None, resp.headers.get("ETag")
    except urllib.error.HTTPError as err:
        if err.code == 304:
            return 304, None, etag
        remaining = err.headers.get("X-RateLimit-Remaining")
        log(f"HTTP {err.code} {path} remaining={remaining}")
        if err.code in (403, 429) and remaining == "0":
            reset = int(err.headers.get("X-RateLimit-Reset", "0"))
            wait = max(30, reset - int(time.time()) + 5)
            log(f"限流，暂停 {wait}s")
            time.sleep(min(wait, 900))
        return err.code, None, etag
    except Exception as err:  # 网络抖动：本轮跳过
        log(f"请求失败 {path}: {err}")
        return 0, None, etag


def notify(title, body, sound="bell", level="active", url=None, group="buildlight"):
    path = f"/{BARK_KEY}/{urllib.parse.quote(title, safe='')}/{urllib.parse.quote(body, safe='')}"
    query = {"group": group, "sound": sound, "level": level, "ttl": "3600"}
    if url:
        query["url"] = url
    full = "https://api.day.app" + path + "?" + urllib.parse.urlencode(query)
    try:
        with urllib.request.urlopen(full, timeout=20) as resp:
            resp.read()
        log(f"推送：{title} | {body}")
    except Exception as err:
        log(f"推送失败：{err}")


# ---------------------------------------------------------------- db

def db():
    conn = sqlite3.connect(STATE_DB, timeout=20)
    conn.execute("PRAGMA journal_mode=WAL")
    conn.executescript(
        """
        CREATE TABLE IF NOT EXISTS etag(key TEXT PRIMARY KEY, value TEXT);
        CREATE TABLE IF NOT EXISTS events(run_id INTEGER, kind TEXT, at INTEGER,
                                          PRIMARY KEY(run_id, kind));
        CREATE TABLE IF NOT EXISTS durations(run_id INTEGER PRIMARY KEY, repo TEXT,
                                             workflow TEXT, branch TEXT,
                                             seconds REAL, at INTEGER);
        CREATE TABLE IF NOT EXISTS bootstrapped(repo TEXT PRIMARY KEY, at INTEGER);
        CREATE TABLE IF NOT EXISTS repo_state(repo TEXT PRIMARY KEY, last_poll INTEGER);
        """
    )
    return conn


def get_etag(conn, key):
    row = conn.execute("SELECT value FROM etag WHERE key=?", (key,)).fetchone()
    return row[0] if row else None


def set_etag(conn, key, value):
    if value:
        conn.execute("INSERT OR REPLACE INTO etag(key,value) VALUES(?,?)", (key, value))


def seen(conn, run_id, kind):
    return conn.execute("SELECT 1 FROM events WHERE run_id=? AND kind=?", (run_id, kind)).fetchone() is not None


def mark(conn, run_id, kind):
    conn.execute("INSERT OR IGNORE INTO events(run_id,kind,at) VALUES(?,?,?)",
                 (run_id, kind, int(time.time())))


# ---------------------------------------------------------------- discovery

def discover(conn, cfg):
    """挑出最近有推送、且确实跑过 Actions 的仓库。"""
    if cfg["repos"] != "auto":
        return list(cfg["repos"])

    status, repos, _ = api("/user/repos?per_page=100&sort=pushed&affiliation=owner")
    if status != 200 or not repos:
        return []

    exclude = set(cfg.get("exclude") or [])
    cutoff = datetime.now(timezone.utc) - timedelta(days=7)
    candidates = []
    for repo in repos:
        full = repo["full_name"]
        if full in exclude:
            continue
        pushed = datetime.fromisoformat(repo["pushed_at"].replace("Z", "+00:00"))
        if pushed < cutoff:
            continue
        candidates.append(full)

    watched = []
    for full in candidates:
        status, data, _ = api(f"/repos/{full}/actions/runs?per_page=1")
        if status == 200 and data and data.get("total_count", 0) > 0:
            watched.append(full)
    log(f"发现 {len(watched)} 个有 Actions 的仓库：{', '.join(watched) or '无'}")
    return watched


# ---------------------------------------------------------------- rules

def failed_step(repo, run_id, conn):
    key = f"jobs:{run_id}"
    status, data, etag = api(f"/repos/{repo}/actions/runs/{run_id}/jobs", get_etag(conn, key))
    if status == 200 and data:
        set_etag(conn, key, etag)
        for job in data.get("jobs", []):
            if job.get("conclusion") in ("failure", "timed_out"):
                for step in job.get("steps", []):
                    if step.get("conclusion") in ("failure", "timed_out"):
                        return step.get("name"), job.get("name")
                return None, job.get("name")
    return None, None


def has_artifacts(repo, run_id, conn):
    key = f"artifacts:{run_id}"
    status, data, etag = api(f"/repos/{repo}/actions/runs/{run_id}/artifacts", get_etag(conn, key))
    if status == 200 and data:
        set_etag(conn, key, etag)
        items = [a for a in data.get("artifacts", []) if not a.get("expired")]
        # 出包才是重点，日志类产物排后面
        items.sort(key=lambda a: 0 if "ipa" in a["name"].lower() else 1)
        return items
    return []


def fmt_duration(seconds):
    seconds = int(max(0, seconds))
    return f"{seconds // 60}:{seconds % 60:02d}"


def record_duration(conn, repo, run):
    started = run.get("run_started_at") or run.get("created_at")
    if not started:
        return None
    begin = datetime.fromisoformat(started.replace("Z", "+00:00"))
    end = datetime.fromisoformat(run["updated_at"].replace("Z", "+00:00"))
    seconds = (end - begin).total_seconds()
    conn.execute(
        "INSERT OR REPLACE INTO durations(run_id,repo,workflow,branch,seconds,at) VALUES(?,?,?,?,?,?)",
        (run["id"], repo, run.get("name") or "", run.get("head_branch") or "", seconds, int(time.time())),
    )
    return seconds


def median_duration(conn, repo, workflow, branch, exclude_run):
    rows = conn.execute(
        "SELECT seconds FROM durations WHERE repo=? AND workflow=? AND branch=? AND run_id<>? "
        "ORDER BY at DESC LIMIT 10",
        (repo, workflow, branch, exclude_run),
    ).fetchall()
    if len(rows) < 3:
        return None
    return statistics.median(row[0] for row in rows)


def in_quiet_hours(cfg):
    hours = cfg.get("quiet_hours") or []
    if not hours:
        return False
    return datetime.now(CST).hour in set(hours)


# ---------------------------------------------------------------- polling

def handle_run(conn, cfg, repo, run, bootstrapping):
    run_id = run["id"]
    status = run.get("status")
    branch = run.get("head_branch") or ""
    workflow = run.get("name") or ""
    number = run.get("run_number")
    link = run.get("html_url")
    label = f"{repo.split('/')[-1]} · {branch} · #{number}"

    # 排队太久
    if status in ("queued", "waiting", "requested", "pending"):
        created = datetime.fromisoformat(run["created_at"].replace("Z", "+00:00"))
        waited = (datetime.now(timezone.utc) - created).total_seconds()
        threshold = cfg["queue_alert_seconds"]
        if waited > threshold and not seen(conn, run_id, "queued"):
            mark(conn, run_id, "queued")
            if not bootstrapping and not in_quiet_hours(cfg):
                notify("排队中 · " + repo.split("/")[-1],
                       f"{label} 已等 {fmt_duration(waited)}，还没分到 runner",
                       sound="bell", url=link)
        return

    if status != "completed":
        return

    conclusion = run.get("conclusion") or ""
    seconds = record_duration(conn, repo, run)

    kind = f"done:{conclusion}"
    if seen(conn, run_id, kind):
        return
    mark(conn, run_id, kind)
    if bootstrapping:
        return

    if conclusion in ("failure", "timed_out", "startup_failure"):
        step, job = failed_step(repo, run_id, conn)
        detail = ""
        if step:
            detail = f"失败于「{step}」"
        elif job:
            detail = f"失败于 {job}"
        body = " · ".join(x for x in [label, fmt_duration(seconds or 0), detail] if x)
        notify("构建失败 · " + repo.split("/")[-1], body,
               sound="alarm", level="timeSensitive", url=link)
        return

    if conclusion == "cancelled":
        if not in_quiet_hours(cfg):
            notify("构建取消 · " + repo.split("/")[-1],
                   " · ".join(x for x in [label, fmt_duration(seconds or 0)] if x),
                   sound="bell", url=link)
        return

    if conclusion != "success":
        return

    # 成功：只在真的出包时提醒
    artifacts = has_artifacts(repo, run_id, conn)
    if not artifacts:
        return

    median = median_duration(conn, repo, workflow, branch, run_id)
    note = ""
    if median and median >= cfg["regression_min_seconds"] and seconds:
        ratio = seconds / median
        if ratio >= cfg["regression_ratio"]:
            note = f"比平时慢 {int((ratio - 1) * 100)}%"

    names = "、".join(a["name"] for a in artifacts[:2])
    body = " · ".join(x for x in [label, fmt_duration(seconds or 0), names, note] if x)
    notify("产物就绪 · " + repo.split("/")[-1], body,
           sound="bell", url=link)


def poll_repo(conn, cfg, repo):
    status, data, etag = api(f"/repos/{repo}/actions/runs?per_page=5", get_etag(conn, repo))
    if status == 304:
        return
    if status != 200 or not data:
        return
    set_etag(conn, repo, etag)

    bootstrapping = conn.execute("SELECT 1 FROM bootstrapped WHERE repo=?", (repo,)).fetchone() is None
    for run in data.get("workflow_runs", []):
        try:
            handle_run(conn, cfg, repo, run, bootstrapping)
        except Exception as err:
            log(f"处理 run {run.get('id')} 出错：{err}")
    if bootstrapping:
        conn.execute("INSERT OR IGNORE INTO bootstrapped(repo,at) VALUES(?,?)",
                     (repo, int(time.time())))
        log(f"{repo} 首次接入，历史状态只记录不推送")


def main():
    os.makedirs(os.path.dirname(STATE_DB), exist_ok=True)
    cfg = load_config()
    conn = db()
    log("监视器启动")

    repos = json.loads(conn.execute("SELECT value FROM etag WHERE key='@repos'").fetchone()[0]) \
        if conn.execute("SELECT 1 FROM etag WHERE key='@repos'").fetchone() else []
    next_discover = 0

    while True:
        try:
            now = time.time()
            if now >= next_discover:
                repos = discover(conn, cfg)
                conn.execute("INSERT OR REPLACE INTO etag(key,value) VALUES('@repos',?)",
                             (json.dumps(repos),))
                next_discover = now + 3600
                conn.commit()

            for repo in repos:
                poll_repo(conn, cfg, repo)
            conn.commit()
        except Exception as err:
            log(f"主循环异常：{err}")
        time.sleep(cfg["poll_seconds"])


if __name__ == "__main__":
    if len(sys.argv) > 1 and sys.argv[1] == "--discover":
        os.makedirs(os.path.dirname(STATE_DB), exist_ok=True)
        conn = db()
        print(json.dumps(discover(conn, load_config()), ensure_ascii=False, indent=2))
        sys.exit(0)
    main()
