{ config, ... }:
{
  sops = {
    defaultSopsFile = ../../secrets/secrets.yaml;
    defaultSopsFormat = "yaml";
    validateSopsFiles = true;

    age.sshKeyPaths = [ "/Users/${config.home.username}/.ssh/id_ed25519" ];

    secrets.jina-api-key = {};

    templates."sops-env.sh" = {
      mode = "0400";
      content = ''
export JINA_API_KEY="${config.sops.placeholder.jina-api-key}"
'';
    };
  };
}
