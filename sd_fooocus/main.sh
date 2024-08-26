#!/bin/bash
set -e

current_dir=$(dirname "$(realpath "$0")")
cd $current_dir
source .env

# Set up a trap to call the error_exit function on ERR signal
trap 'error_exit "### ERROR ###"' ERR


echo "### Setting up Stable Diffusion Fooocus ###"
log "Setting up Stable Diffusion Fooocus"
if [[ "$REINSTALL_SD_FOOOCUS" || ! -f "/tmp/sd_fooocus.prepared" ]]; then

    
    if [ -f $REPO_DIR/webui.py ]; then
      sed -i "s|share=args_manager.args.share,root_path='/sd-fooocus'|share=args_manager.args.share|g" $REPO_DIR/webui.py
    fi

    TARGET_REPO_URL="https://github.com/lllyasviel/Fooocus.git" \
    TARGET_REPO_DIR=$REPO_DIR \
    TARGET_REPO_BRANCH="main" \
    UPDATE_REPO=$SD_FOOOCUS_UPDATE_REPO \
    UPDATE_REPO_COMMIT=$SD_FOOOCUS_UPDATE_REPO_COMMIT \
    prepare_repo 

    symlinks=(
        "$REPO_DIR/outputs:$IMAGE_OUTPUTS_DIR/stable-diffusion-fooocus"
        "$MODEL_DIR:$WORKING_DIR/models"
        "$MODEL_DIR/sd:$LINK_MODEL_TO"
        "$MODEL_DIR/lora:$LINK_LORA_TO"
        "$MODEL_DIR/vae:$LINK_VAE_TO"
        "$MODEL_DIR/hypernetwork:$LINK_HYPERNETWORK_TO"
        "$MODEL_DIR/controlnet:$LINK_CONTROLNET_TO"
        "$MODEL_DIR/embedding:$LINK_EMBEDDING_TO"
    )
    prepare_link  "${symlinks[@]}"
    rm -rf $VENV_DIR/sd_fooocus-env
    
    
    python3.10 -m venv $VENV_DIR/sd_fooocus-env
    
    source $VENV_DIR/sd_fooocus-env/bin/activate

    pip install pip==24.0
    pip install --upgrade wheel setuptools
    
    pip install pygit2 packaging

    cd $REPO_DIR
    pip install torch==2.1.0 torchvision==0.16.0 --extra-index-url https://download.pytorch.org/whl/cu121
    pip install -r requirements_versions.txt
    
    touch /tmp/sd_fooocus.prepared
else
    
    source $VENV_DIR/sd_fooocus-env/bin/activate
    
fi
log "Finished Preparing Environment for Stable Diffusion Fooocus"


if [[ -z "$SKIP_MODEL_DOWNLOAD" ]]; then
  echo "### Downloading Model for Stable Diffusion Fooocus ###"
  log "Downloading Model for Stable Diffusion Fooocus"
  bash $current_dir/../utils/sd_model_download/main.sh
  log "Finished Downloading Models for Stable Diffusion Fooocus"
else
  log "Skipping Model Download for Stable Diffusion Fooocus"
fi

if ! grep -q "root_path" $REPO_DIR/webui.py; then
  sed -i "s|share=args_manager.args.share|share=args_manager.args.share,root_path='/sd-fooocus'|g" $REPO_DIR/webui.py
fi


if [[ -z "$INSTALL_ONLY" ]]; then
  echo "### Starting Stable Diffusion Fooocus ###"
  log "Starting Stable Diffusion Fooocus"
  cd $REPO_DIR
  PYTHONUNBUFFERED=1 service_loop "python launch.py --port 7015" > $LOG_DIR/sd_fooocus.log 2>&1 &
  echo $! > /tmp/sd_fooocus.pid
fi


send_to_discord "Stable Diffusion Fooocus Started"

if env | grep -q "PAPERSPACE"; then
  send_to_discord "Link: https://$PAPERSPACE_FQDN/sd-fooocus/"
fi


if [[ -n "${CF_TOKEN}" ]]; then
  if [[ "$RUN_SCRIPT" != *"sd_fooocus"* ]]; then
    export RUN_SCRIPT="$RUN_SCRIPT,sd_fooocus"
  fi
  bash $current_dir/../cloudflare_reload.sh
fi

echo "### Done ###"