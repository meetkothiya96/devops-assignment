#!/usr/bin/env python3
"""
deploy.py — Deployment automation script

TASK: Implement a deployment script for the video-analytics service.

Requirements:
  - argparse CLI with subcommands: deploy, rollback, status
  - deploy: takes --environment (staging/production), --image-tag, --dry-run
  - rollback: takes --environment, --revision (optional, defaults to previous)
  - status: takes --environment, shows current deployment state
  - Health check function that verifies deployment success
  - Rollback function that reverts to previous version on failure
  - Logging throughout

You don't need actual kubectl/AWS calls — implement the logic with
print statements or subprocess calls that would work in a real environment.
"""

import argparse
import logging
import sys
import time
import random


# -----------------------------
# Logging
# -----------------------------

def setup_logging():
    """Configure logging."""
    logging.basicConfig(
        level=logging.INFO,
        format="%(asctime)s [%(levelname)s] %(message)s",
        handlers=[logging.StreamHandler(sys.stdout)]
    )


# -----------------------------
# Argument Parsing
# -----------------------------

def parse_args():
    """Parse command line arguments with subcommands."""
    parser = argparse.ArgumentParser(
        description="Deployment automation for video-analytics service"
    )

    subparsers = parser.add_subparsers(dest="command", required=True)

    # --- deploy ---
    deploy_parser = subparsers.add_parser("deploy", help="Deploy application")
    deploy_parser.add_argument(
        "--environment",
        required=True,
        choices=["staging", "production"],
        help="Target environment"
    )
    deploy_parser.add_argument(
        "--image-tag",
        required=True,
        help="Container image tag to deploy"
    )
    deploy_parser.add_argument(
        "--dry-run",
        action="store_true",
        help="Show actions without executing"
    )

    # --- rollback ---
    rollback_parser = subparsers.add_parser("rollback", help="Rollback deployment")
    rollback_parser.add_argument(
        "--environment",
        required=True,
        choices=["staging", "production"],
        help="Target environment"
    )
    rollback_parser.add_argument(
        "--revision",
        help="Revision to rollback to (defaults to previous)"
    )

    # --- status ---
    status_parser = subparsers.add_parser("status", help="Check deployment status")
    status_parser.add_argument(
        "--environment",
        required=True,
        choices=["staging", "production"],
        help="Target environment"
    )

    return parser.parse_args()


# -----------------------------
# Health Check
# -----------------------------

def health_check(environment, timeout=300):
    """
    Check deployment health after rollout.
    Simulates readiness/liveness checks.
    """
    logging.info("Starting health check for %s environment", environment)

    elapsed = 0
    interval = 10

    while elapsed < timeout:
        logging.info("Checking pod and service health...")
        time.sleep(interval)
        elapsed += interval

        # Simulated success/failure
        if random.choice([True, True, True, False]):
            logging.info("Deployment healthy")
            return True

        logging.warning("Pods not ready yet... retrying")

    logging.error("Health check timed out after %s seconds", timeout)
    return False


# -----------------------------
# Deploy Logic
# -----------------------------

def deploy(environment, image_tag, dry_run=False):
    """Deploy the application to the specified environment."""
    logging.info(
        "Starting deployment to %s with image tag %s",
        environment,
        image_tag
    )

    if dry_run:
        logging.info("[DRY-RUN] helm upgrade --install video-analytics")
        logging.info("[DRY-RUN] --set image.tag=%s", image_tag)
        return

    logging.info("Applying Helm release...")
    print(
        f"helm upgrade --install video-analytics "
        f"./helm --namespace {environment} "
        f"--set image.tag={image_tag}"
    )

    if not health_check(environment):
        logging.error("Deployment failed health checks — initiating rollback")
        rollback(environment)
        sys.exit(1)

    logging.info("Deployment to %s completed successfully", environment)


# -----------------------------
# Rollback Logic
# -----------------------------

def rollback(environment, revision=None):
    """Rollback to a previous deployment revision."""
    logging.warning("Starting rollback for %s environment", environment)

    if revision:
        logging.info("Rolling back to revision %s", revision)
        print(
            f"helm rollback video-analytics {revision} "
            f"--namespace {environment}"
        )
    else:
        logging.info("Rolling back to previous revision")
        print(
            f"helm rollback video-analytics "
            f"--namespace {environment}"
        )

    logging.info("Rollback completed")


# -----------------------------
# Status Logic
# -----------------------------

def status(environment):
    """Show current deployment status."""
    logging.info("Fetching deployment status for %s environment", environment)

    print(
        f"kubectl get deployment video-analytics "
        f"-n {environment}"
    )
    print(
        f"kubectl get pods -n {environment}"
    )
    print(
        f"kubectl get svc -n {environment}"
    )


# -----------------------------
# Main Entrypoint
# -----------------------------

def main():
    setup_logging()
    args = parse_args()

    if args.command == "deploy":
        deploy(
            environment=args.environment,
            image_tag=args.image_tag,
            dry_run=args.dry_run
        )

    elif args.command == "rollback":
        rollback(
            environment=args.environment,
            revision=args.revision
        )

    elif args.command == "status":
        status(args.environment)

    else:
        logging.error("Unknown command")
        sys.exit(1)


if __name__ == "__main__":
    main()