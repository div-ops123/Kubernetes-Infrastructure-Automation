import os
import redis

def increment_click(short_code):
    """Increment the click count for a given short code in Redis."""
    redis_url = os.environ['REDIS_URL']
    r = redis.from_url(redis_url)
    r.incr(f'clicks:{short_code}')  # Atomically increment the click count