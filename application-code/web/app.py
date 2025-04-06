import os
import sys
import random
import string
from flask import Flask, request, render_template, redirect, url_for, abort
import redis
from rq import Queue

# Get the parent directory
parent_dir = os.path.abspath(os.path.join(os.path.dirname(__file__), '..'))
# Add the parent directory to sys.path
sys.path.insert(0, parent_dir)

from jobs.analytics import increment_click

app = Flask(__name__)

# Connect to Redis using the REDIS_URL environment variable
redis_url = os.environ['REDIS_URL']
r = redis.from_url(redis_url)
q = Queue(connection=r)

def generate_short_code():
    """Generate a unique 6-character short code using alphanumeric characters."""
    characters = string.ascii_letters + string.digits  # a-z, A-Z, 0-9
    while True:
        short_code = ''.join(random.choice(characters) for _ in range(6))
        if not r.exists(f'url:{short_code}'):  # Check if the short code is unused
            return short_code

@app.route('/')
def index():
    """Render the homepage with the URL submission form."""
    return render_template('index.html')

@app.route('/shorten', methods=['POST'])
def shorten():
    """Handle URL shortening and display the shortened URL."""
    original_url = request.form['url']  # Get the URL from the form
    short_code = generate_short_code()  # Generate a unique short code
    r.set(f'url:{short_code}', original_url)  # Store the mapping in Redis
    short_url = url_for('redirect_to_url', short_code=short_code, _external=True)  # Generate full URL
    return render_template('index.html', short_url=short_url)  # Re-render with shortened URL

@app.route('/<short_code>')
def redirect_to_url(short_code):
    """Redirect to the original URL and enqueue a job to track the click."""
    original_url = r.get(f'url:{short_code}')  # Look up the original URL in Redis
    if original_url:
        original_url = original_url.decode('utf-8')  # Decode bytes to string
        q.enqueue(increment_click, short_code)  # Enqueue job to increment click count
        return redirect(original_url)  # Redirect to the original URL
    else:
        abort(404)  # Return 404 if short code not found

# /list route to see all your shortened URLs
@app.route('/list')
def list_urls():
    try:
        url_keys = r.keys('url:*')
        urls = {key.decode('utf-8')[4:]: r.get(key).decode('utf-8') for key in url_keys}
        return render_template('list.html', urls=urls)
    except Exception as e:
        return f"Error fetching URLs: {str(e)}", 500

if __name__ == '__main__':
    app.run(host='0.0.0.0', port=5000)  # Run on all interfaces, port 5000