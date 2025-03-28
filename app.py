import os, json
from flask import Flask, redirect, url_for, render_template, session, request
from flask_session import Session
import msal
import EntraApp.app_config as app_config

app = Flask(__name__)
app.config.from_object(app_config)

# Add session configuration
app.config['SESSION_TYPE'] = 'filesystem'  # Using filesystem for session storage
app.config['SESSION_PERMANENT'] = False
app.config['SECRET_KEY'] = os.getenv("SECRET_KEY")  # Required for sessions

Session(app)

# MSAL Configuration
client = msal.ConfidentialClientApplication(
    app_config.CLIENT_ID,
    authority=app_config.AUTHORITY,
    client_credential=app_config.CLIENT_SECRET,
)

@app.route('/')
def index():
    if not session.get("user"):
        return redirect(url_for("login"))
    return render_template('index.html', user=session["user"])

@app.route('/login')
def login():
    auth_url = client.get_authorization_request_url(
        scopes=app_config.SCOPE,
        redirect_uri=url_for('authorized', _external=True)
    )
    return redirect(auth_url)

@app.route('/gettoken')  # This should match your redirect URI
def authorized():
    if request.args.get('code'):
        result = client.acquire_token_by_authorization_code(
            request.args['code'],
            scopes=app_config.SCOPE,
            redirect_uri=url_for('authorized', _external=True)
        )
        if "access_token" in result:
            with open("token.json", "w") as f:
                json.dump(result, f, indent=4)
            session["user"] = result["id_token_claims"]
            return redirect(url_for('index'))
        return "Login failed: " + result.get("error_description", "Unknown error")
    return redirect(url_for('index'))

@app.route('/logout')
def logout():
    # Clear the Flask session
    session.clear()
    
    # Construct the logout URL
    logout_url = f"{app_config.AUTHORITY}/oauth2/v2.0/logout"
    logout_params = {
        "post_logout_redirect_uri": url_for("index", _external=True),
        # Optional: Add logout_hint using the user's UPN or email if available
        # "logout_hint": session.get("user", {}).get("preferred_username", "")
    }
    
    # Redirect to Entra ID logout endpoint
    from urllib.parse import urlencode
    return redirect(f"{logout_url}?{urlencode(logout_params)}")

if __name__ == '__main__':
    app.run(debug=True, port=5030, host="0.0.0.0")