"""
Webhook handlers for Git providers (GitHub, GitLab, etc.)
"""
from fastapi import APIRouter, Request, HTTPException, Header, Depends
from sqlalchemy.orm import Session
import hashlib
import hmac
import json
import structlog
from typing import Optional

from src.database import get_db
from src.models import Pipeline, Repository, User, PipelineStep
from src.config import get_settings
from src.schemas import PipelineCreate

logger = structlog.get_logger()
router = APIRouter(prefix="/api/v1/webhooks", tags=["webhooks"])

def verify_github_signature(payload: bytes, signature: str, secret: str) -> bool:
    """Verify GitHub webhook signature"""
    if not signature.startswith('sha256='):
        return False
    
    expected = hmac.new(
        secret.encode(),
        payload,
        hashlib.sha256
    ).hexdigest()
    
    return hmac.compare_digest(f"sha256={expected}", signature)

def verify_gitlab_signature(payload: bytes, token: str, secret: str) -> bool:
    """Verify GitLab webhook token"""
    return hmac.compare_digest(token, secret)

@router.post("/github")
async def github_webhook(
    request: Request,
    x_github_event: str = Header(...),
    x_hub_signature_256: Optional[str] = Header(None),
    db: Session = Depends(get_db)
):
    """Handle GitHub webhook events"""
    settings = get_settings()
    body = await request.body()
    
    # Verify signature if secret is configured
    if settings.webhook_secret and x_hub_signature_256:
        if not verify_github_signature(body, x_hub_signature_256, settings.webhook_secret):
            logger.warning("Invalid GitHub webhook signature")
            raise HTTPException(status_code=401, detail="Invalid signature")
    
    try:
        payload = json.loads(body)
        logger.info("Received GitHub webhook", event=x_github_event, repo=payload.get('repository', {}).get('full_name'))
        
        if x_github_event == "push":
            return await handle_github_push(payload, db)
        elif x_github_event == "pull_request":
            return await handle_github_pull_request(payload, db)
        else:
            logger.info("Unhandled GitHub event", event=x_github_event)
            return {"message": f"Event {x_github_event} received but not processed"}
            
    except json.JSONDecodeError:
        raise HTTPException(status_code=400, detail="Invalid JSON payload")
    except Exception as e:
        logger.error("Error processing GitHub webhook", error=str(e))
        raise HTTPException(status_code=500, detail="Internal server error")

@router.post("/gitlab")
async def gitlab_webhook(
    request: Request,
    x_gitlab_event: str = Header(...),
    x_gitlab_token: Optional[str] = Header(None),
    db: Session = Depends(get_db)
):
    """Handle GitLab webhook events"""
    settings = get_settings()
    body = await request.body()
    
    # Verify token if secret is configured
    if settings.webhook_secret and x_gitlab_token:
        if not verify_gitlab_signature(body, x_gitlab_token, settings.webhook_secret):
            logger.warning("Invalid GitLab webhook token")
            raise HTTPException(status_code=401, detail="Invalid token")
    
    try:
        payload = json.loads(body)
        logger.info("Received GitLab webhook", event=x_gitlab_event, project=payload.get('project', {}).get('path_with_namespace'))
        
        if x_gitlab_event == "Push Hook":
            return await handle_gitlab_push(payload, db)
        elif x_gitlab_event == "Merge Request Hook":
            return await handle_gitlab_merge_request(payload, db)
        else:
            logger.info("Unhandled GitLab event", event=x_gitlab_event)
            return {"message": f"Event {x_gitlab_event} received but not processed"}
            
    except json.JSONDecodeError:
        raise HTTPException(status_code=400, detail="Invalid JSON payload")
    except Exception as e:
        logger.error("Error processing GitLab webhook", error=str(e))
        raise HTTPException(status_code=500, detail="Internal server error")

async def handle_github_push(payload: dict, db: Session):
    """Handle GitHub push events"""
    repo_url = payload['repository']['clone_url']
    branch = payload['ref'].replace('refs/heads/', '')
    commit_hash = payload['head_commit']['id']
    commit_message = payload['head_commit']['message']
    
    # Find repository in database
    repository = db.query(Repository).filter(Repository.url.contains(payload['repository']['name'])).first()
    if not repository:
        logger.warning("Repository not found", repo=payload['repository']['full_name'])
        return {"message": "Repository not configured"}
    
    # Create pipeline
    pipeline = Pipeline(
        name=f"Push to {branch}",
        repository_id=repository.id,
        commit_hash=commit_hash,
        commit_message=commit_message,
        branch=branch,
        status="pending"
    )
    
    db.add(pipeline)
    db.commit()
    db.refresh(pipeline)
    
    # Create pipeline steps
    steps = [
        {"name": "Checkout", "order": 1},
        {"name": "Build", "order": 2},
        {"name": "Test", "order": 3},
        {"name": "Security Scan", "order": 4},
        {"name": "Deploy", "order": 5}
    ]
    
    for step in steps:
        pipeline_step = PipelineStep(
            pipeline_id=pipeline.id,
            step_name=step["name"],
            step_order=step["order"],
            status="pending"
        )
        db.add(pipeline_step)
    
    db.commit()
    
    # Here you would trigger your actual CI/CD system
    # For now, we'll just log and return
    logger.info("Pipeline created", pipeline_id=str(pipeline.id), commit=commit_hash[:8])
    
    return {
        "message": "Pipeline triggered",
        "pipeline_id": str(pipeline.id),
        "commit": commit_hash[:8],
        "branch": branch
    }

async def handle_gitlab_push(payload: dict, db: Session):
    """Handle GitLab push events"""
    repo_url = payload['project']['git_http_url']
    branch = payload['ref'].replace('refs/heads/', '')
    commit_hash = payload['checkout_sha']
    commit_message = payload['commits'][0]['message'] if payload['commits'] else "No commit message"
    
    # Find repository in database
    repository = db.query(Repository).filter(Repository.url.contains(payload['project']['name'])).first()
    if not repository:
        logger.warning("Repository not found", project=payload['project']['path_with_namespace'])
        return {"message": "Repository not configured"}
    
    # Create pipeline (similar to GitHub)
    pipeline = Pipeline(
        name=f"Push to {branch}",
        repository_id=repository.id,
        commit_hash=commit_hash,
        commit_message=commit_message,
        branch=branch,
        status="pending"
    )
    
    db.add(pipeline)
    db.commit()
    db.refresh(pipeline)
    
    logger.info("GitLab pipeline created", pipeline_id=str(pipeline.id), commit=commit_hash[:8])
    
    return {
        "message": "Pipeline triggered",
        "pipeline_id": str(pipeline.id),
        "commit": commit_hash[:8],
        "branch": branch
    }

async def handle_github_pull_request(payload: dict, db: Session):
    """Handle GitHub pull request events"""
    if payload['action'] not in ['opened', 'synchronize', 'reopened']:
        return {"message": "PR action not processed"}
    
    pr_number = payload['number']
    branch = payload['pull_request']['head']['ref']
    commit_hash = payload['pull_request']['head']['sha']
    
    # Create PR pipeline
    repository = db.query(Repository).filter(Repository.url.contains(payload['repository']['name'])).first()
    if not repository:
        return {"message": "Repository not configured"}
    
    pipeline = Pipeline(
        name=f"PR #{pr_number} - {branch}",
        repository_id=repository.id,
        commit_hash=commit_hash,
        commit_message=f"Pull Request #{pr_number}",
        branch=branch,
        status="pending"
    )
    
    db.add(pipeline)
    db.commit()
    db.refresh(pipeline)
    
    logger.info("PR pipeline created", pipeline_id=str(pipeline.id), pr=pr_number)
    
    return {
        "message": "PR pipeline triggered",
        "pipeline_id": str(pipeline.id),
        "pr_number": pr_number
    }

async def handle_gitlab_merge_request(payload: dict, db: Session):
    """Handle GitLab merge request events"""
    if payload['object_attributes']['action'] not in ['open', 'update', 'reopen']:
        return {"message": "MR action not processed"}
    
    mr_iid = payload['object_attributes']['iid']
    branch = payload['object_attributes']['source_branch']
    commit_hash = payload['object_attributes']['last_commit']['id']
    
    # Create MR pipeline
    repository = db.query(Repository).filter(Repository.url.contains(payload['project']['name'])).first()
    if not repository:
        return {"message": "Repository not configured"}
    
    pipeline = Pipeline(
        name=f"MR !{mr_iid} - {branch}",
        repository_id=repository.id,
        commit_hash=commit_hash,
        commit_message=f"Merge Request !{mr_iid}",
        branch=branch,
        status="pending"
    )
    
    db.add(pipeline)
    db.commit()
    db.refresh(pipeline)
    
    logger.info("MR pipeline created", pipeline_id=str(pipeline.id), mr=mr_iid)
    
    return {
        "message": "MR pipeline triggered",
        "pipeline_id": str(pipeline.id),
        "mr_number": mr_iid
    }
