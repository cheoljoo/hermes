"""EXAONE (LGE AILab EXACODE SWE API) provider profile.

Connection details mirror sage.py's ``_get_llm_client``: an OpenAI-compatible
endpoint reached via the ``openai`` SDK, with two fixed identifying headers
and a Bearer API key. No REST /models catalog is exposed, so live model
listing is disabled and the single known model id is used as the fallback.
"""

from providers import register_provider
from providers.base import ProviderProfile

exaone = ProviderProfile(
    name="exaone",
    aliases=("exacode",),
    display_name="EXAONE (LGE AILab)",
    description="LGE AILab internal EXACODE SWE API",
    env_vars=("EXAONE_API_KEY",),
    base_url="http://exacode-chat.lge.com/v1",
    default_headers={"X-Title": "EXACODE SWE(API)", "X-Model": "Chat-EXACODE-A"},
    fallback_models=("Chat-EXACODE-A",),
    supports_health_check=False,
)

register_provider(exaone)
