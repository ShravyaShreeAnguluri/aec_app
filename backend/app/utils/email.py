import smtplib
from email.message import EmailMessage
from app.config import EMAIL, APP_PASSWORD

SMTP_SERVER = "smtp.gmail.com"
SMTP_PORT = 465

def send_otp_email(receiver_email: str, otp: str):
    msg = EmailMessage()
    msg["Subject"] = "Your Login OTP"
    msg["From"] = EMAIL
    msg["To"] = receiver_email

    msg.set_content(
        f"Your OTP is {otp}. It is valid for 5 minutes."
    )

    try:
        with smtplib.SMTP_SSL(SMTP_SERVER, SMTP_PORT) as server:
            server.login(EMAIL, APP_PASSWORD)
            server.send_message(msg)
    except Exception as e:
        print("EMAIL ERROR:", e)
        raise

def send_reset_email(receiver_email: str, reset_link: str):
    msg = EmailMessage()
    msg["Subject"] = "Reset Your Password"
    msg["From"] = EMAIL
    msg["To"] = receiver_email

    msg.set_content("Click the button below to reset your password.")

    msg.add_alternative(f"""
    <html>
      <body>
        <p>Click the button below to reset your password.</p>

        <a href="{reset_link}" 
           style="
             background-color:#4CAF50;
             color:white;
             padding:12px 24px;
             text-decoration:none;
             border-radius:6px;
             font-weight:bold;
             display:inline-block;">
           Reset Password
        </a>

        <p>This link is valid for 15 minutes.</p>
      </body>
    </html>
    """, subtype="html")

    with smtplib.SMTP_SSL(SMTP_SERVER, SMTP_PORT) as server:
        server.login(EMAIL, APP_PASSWORD)
        server.send_message(msg)
