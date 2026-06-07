"""FortiFlex API endpoints — authenticate and fetch configs/serial numbers."""
import logging
import httpx
from fastapi import APIRouter, HTTPException
from pydantic import BaseModel
from typing import List, Optional

logger = logging.getLogger(__name__)

router = APIRouter(prefix="/api/fortiflex", tags=["fortiflex"])

AUTH_URL = "https://customerapiauth.fortinet.com/api/v1/oauth/token/"
FLEX_BASE = "https://support.fortinet.com/ES/api/fortiflex/v2"


class FlexCredentials(BaseModel):
    username: str
    password: str


class FlexSerialsRequest(BaseModel):
    username: str
    password: str
    config_ids: List[str]


async def _get_token(username: str, password: str) -> str:
    async with httpx.AsyncClient(timeout=15) as client:
        resp = await client.post(AUTH_URL, json={
            "username": username,
            "password": password,
            "client_id": "flexvm",
            "grant_type": "password",
        })
    if resp.status_code != 200:
        logger.warning("FortiFlex auth failed: %s %s", resp.status_code, resp.text)
        raise HTTPException(status_code=401, detail="FortiFlex authentication failed — check username and password")
    return resp.json()["access_token"]


@router.post("/configs")
async def list_configs(creds: FlexCredentials):
    """Authenticate and return all FortiFlex configuration IDs and names.

    configs/list requires a programSerialNumber, so we first call
    programs/list to discover all program serial numbers, then fetch
    configs for each program.
    """
    token = await _get_token(creds.username, creds.password)
    headers = {"Authorization": f"Bearer {token}", "Content-Type": "application/json"}

    async with httpx.AsyncClient(timeout=15) as client:
        # Step 1: list programs to get programSerialNumbers
        prog_resp = await client.post(
            f"{FLEX_BASE}/programs/list",
            headers=headers,
            json={},
        )
        if prog_resp.status_code != 200:
            logger.warning("FortiFlex programs/list failed: %s %s", prog_resp.status_code, prog_resp.text)
            raise HTTPException(status_code=prog_resp.status_code, detail="Failed to fetch FortiFlex programs")
        programs = prog_resp.json().get("programs", []) or []

        # Step 2: fetch configs for each program
        all_configs = []
        for program in programs:
            psn = program.get("serialNumber") or program.get("programSerialNumber")
            if not psn:
                continue
            cfg_resp = await client.post(
                f"{FLEX_BASE}/configs/list",
                headers=headers,
                json={"programSerialNumber": psn},
            )
            if cfg_resp.status_code != 200:
                logger.warning("FortiFlex configs/list failed for program %s: %s", psn, cfg_resp.status_code)
                continue
            configs = cfg_resp.json().get("configs", []) or []
            all_configs.extend(configs)

    return {
        "configs": [
            {
                "id": str(c.get("id", "")),
                "name": c.get("name") or str(c.get("id", "")),
            }
            for c in all_configs
            if c.get("id")
        ]
    }


@router.post("/serials")
async def list_serials(req: FlexSerialsRequest):
    """Authenticate and return serial numbers for the given configuration IDs."""
    token = await _get_token(req.username, req.password)
    all_serials = []
    async with httpx.AsyncClient(timeout=15) as client:
        for config_id in req.config_ids:
            if not config_id:
                continue
            resp = await client.post(
                f"{FLEX_BASE}/entitlements/list",
                headers={"Authorization": f"Bearer {token}", "Content-Type": "application/json"},
                json={"configId": int(config_id)},
            )
            if resp.status_code != 200:
                logger.warning("FortiFlex entitlements/list failed for configId %s: %s", config_id, resp.status_code)
                continue
            data = resp.json()
            for e in data.get("entitlements", []):
                sn = e.get("serialNumber")
                if sn:
                    all_serials.append(sn)
    # Deduplicate while preserving order
    seen = set()
    unique_serials = [sn for sn in all_serials if not (sn in seen or seen.add(sn))]
    return {"serials": unique_serials}
