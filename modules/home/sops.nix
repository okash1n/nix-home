{ config, ... }:
{
  sops = {
    defaultSopsFile = ../../secrets/secrets.yaml;
    defaultSopsFormat = "yaml";
    validateSopsFiles = true;

    age.sshKeyPaths = [ "/Users/${config.home.username}/.ssh/id_ed25519" ];

    secrets.jina-api-key = {};
    secrets.vsce-pat = {};
    secrets.asana-mcp-client-id = {};
    secrets.asana-mcp-client-secret = {};

    templates."sops-env.sh" = {
      mode = "0400";
      content = ''
export JINA_API_KEY="${config.sops.placeholder.jina-api-key}"
export VSCE_PAT="${config.sops.placeholder.vsce-pat}"
export ASANA_MCP_CLIENT_ID="${config.sops.placeholder.asana-mcp-client-id}"
export ASANA_MCP_CLIENT_SECRET="${config.sops.placeholder.asana-mcp-client-secret}"
'';
    };
  };
}
