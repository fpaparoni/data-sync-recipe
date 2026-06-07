import os
import time
import json
import psycopg2
import redis
import traceback

PG_HOST = os.environ["PG_HOST"]
PG_DB = os.environ["PG_DB"]
PG_USER = os.environ["PG_USER"]
PG_PASSWORD = os.environ["PG_PASSWORD"]

REDIS_HOST = os.environ["REDIS_HOST"]
REDIS_PASSWORD = os.environ["REDIS_PASSWORD"]

SYNC_INTERVAL = int(os.getenv("SYNC_INTERVAL", "10"))


def connect_pg():
    print(f"[PG] connecting to {PG_HOST}/{PG_DB}")
    return psycopg2.connect(
        host=PG_HOST,
        dbname=PG_DB,
        user=PG_USER,
        password=PG_PASSWORD
    )


def connect_redis():
    print(f"[REDIS] connecting to {REDIS_HOST}")
    return redis.Redis(
        host=REDIS_HOST,
        password=REDIS_PASSWORD,
        decode_responses=True
    )


def sync(pg, r):
    print("[SYNC] starting cycle")

    cur = pg.cursor()

    cur.execute("SELECT id, username, email FROM demo.users")
    rows = cur.fetchall()

    print(f"[PG] rows fetched: {len(rows)}")

    if len(rows) == 0:
        print("[WARN] no rows in postgres table")

    for (id, username, email) in rows:
        key = f"user:{id}"
        value = json.dumps({
            "id": id,
            "username": username,
            "email": email
        })

        print(f"[REDIS] SET {key}")

        try:
            r.set(key, value, ex=3600)
        except Exception as e:
            print(f"[REDIS ERROR] {e}")


def main():
    print("[BOOT] postgres-redis-sync starting")

    pg = connect_pg()
    r = connect_redis()

    while True:
        try:
            sync(pg, r)
            print("[SYNC] cycle complete")

        except Exception as e:
            print("[FATAL SYNC ERROR]")
            traceback.print_exc()

            pg = connect_pg()
            r = connect_redis()

        time.sleep(SYNC_INTERVAL)


if __name__ == "__main__":
    main()