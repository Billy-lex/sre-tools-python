import ssl
import socket
import sys
import logging
from datetime import datetime, timezone

logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s | %(levelname)s | %(message)s"
)

DEFAULT_PORT = 443
WARN_DAYS = 30


def check_ssl_cert(host: str, port: int = DEFAULT_PORT) -> None:
    """Check SSL certificate expiration for a given host."""
    logging.info(f"Checking SSL certificate for {host}:{port}")

    try:
        ctx = ssl.create_default_context()
        with ctx.wrap_socket(socket.socket(), server_hostname=host) as s:
            s.settimeout(10)
            s.connect((host, port))
            cert = s.getpeercert()
    except ssl.SSLCertVerificationError as e:
        logging.error(f"SSL verification failed: {e}")
        sys.exit(1)
    except Exception as e:
        logging.error(f"Connection failed: {e}")
        sys.exit(1)

    subject = dict(x[0] for x in cert["subject"])
    issuer = dict(x[0] for x in cert["issuer"])
    not_after = cert["notAfter"]
    expiry = datetime.strptime(not_after, "%b %d %H:%M:%S %Y %Z").replace(tzinfo=timezone.utc)
    now = datetime.now(timezone.utc)
    days_left = (expiry - now).days

    logging.info(f"Subject:  {subject.get('commonName', 'N/A')}")
    logging.info(f"Issuer:   {issuer.get('organizationName', 'N/A')}")
    logging.info(f"Expiry:   {expiry.strftime('%Y-%m-%d %H:%M:%S UTC')}")
    logging.info(f"Days left: {days_left}")

    if days_left < 0:
        logging.error("Certificate has EXPIRED!")
    elif days_left <= WARN_DAYS:
        logging.warning(f"Certificate expires within {WARN_DAYS} days!")
    else:
        logging.info("Certificate is valid.")


def main() -> None:
    if len(sys.argv) < 2:
        logging.error(f"Usage: {sys.argv[0]} <host> [port]")
        sys.exit(1)

    host = sys.argv[1]
    port = int(sys.argv[2]) if len(sys.argv) >= 3 else DEFAULT_PORT
    check_ssl_cert(host, port)


if __name__ == "__main__":
    main()
