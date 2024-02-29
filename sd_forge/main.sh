#!/bin/bash
set -e

current_dir=$(dirname "$(realpath "$0")")
cd $current_dir
source .env

# Set up a trap to call the error_exit function on ERR signal
trap 'error_exit "### ERROR ###"' ERR


echo "### Setting up Stable Diffusion Forge ###"
log "Setting up Stable Diffusion Forge"
if [[ "$REINSTALL_SD_FORGE" || ! -f "/tmp/sd_forge.prepared" ]]; then

    TARGET_REPO_URL="https://github.com/lllyasviel/stable-diffusion-webui-forge.git" \
    TARGET_REPO_DIR=$REPO_DIR \
    TARGET_REPO_BRANCH="main" \
    UPDATE_REPO=$SD_FORGE_UPDATE_REPO \
    UPDATE_REPO_COMMIT=$SD_FORGE_UPDATE_REPO_COMMIT \
    prepare_repo 

    symlinks=(
        "$REPO_DIR/output:$IMAGE_OUTPUTS_DIR/stable-diffusion-forge"
        "$MODEL_DIR:$WORKING_DIR/models"
        "$MODEL_DIR/sd:$LINK_MODEL_TO"
        "$MODEL_DIR/lora:$LINK_LORA_TO"
        "$MODEL_DIR/vae:$LINK_VAE_TO"
        "$MODEL_DIR/hypernetwork:$LINK_HYPERNETWORK_TO"
        "$MODEL_DIR/controlnet:$LINK_CONTROLNET_TO"
        "$MODEL_DIR/embedding:$LINK_EMBEDDING_TO"
    )
    prepare_link  "${symlinks[@]}"
    rm -rf $VENV_DIR/sd_forge-env
    
    
    python3.10 -m venv $VENV_DIR/sd_forge-env
    
    source $VENV_DIR/sd_forge-env/bin/activate

    pip install --upgrade pip
    pip install --upgrade wheel setuptools
    
    pip install torch==2.1.2 torchvision torchaudio protobuf lxml

    export PYTHONPATH="$PYTHONPATH:$REPO_DIR"
    # must run inside webui dir since env['PYTHONPATH'] = os.path.abspath(".") existing in launch.py
    cd $REPO_DIR
    python $current_dir/preinstall.py
    cd $current_dir

    pip install xformers==0.0.23.post1
    
    touch /tmp/sd_forge.prepared
else
    
    source $VENV_DIR/sd_forge-env/bin/activate
    
fi
log "Finished Preparing Environment for Stable Diffusion Forge"


if [[ -z "$SKIP_MODEL_DOWNLOAD" ]]; then
  echo "### Downloading Model for Stable Diffusion Forge ###"
  log "Downloading Model for Stable Diffusion Forge"
  bash $current_dir/../utils/sd_model_download/main.sh
  log "Finished Downloading Models for Stable Diffusion Forge"
else
  log "Skipping Model Download for Stable Diffusion Forge"
fi




if [[ -z "$INSTALL_ONLY" ]]; then
  echo "### Starting Stable Diffusion Forge ###"
  log "Starting Stable Diffusion Forge"
  cd $REPO_DIR
  auth=""
  if [[ -n "${SD_FORGE_GRADIO_AUTH}" ]]; then
    auth="--gradio-auth ${SD_FORGE_GRADIO_AUTH}"
  fi
  PYTHONUNBUFFERED=1 service_loop "python webui.py --xformers --port $SD_FORGE_PORT --subpath sd-forge $auth --controlnet-dir $MODEL_DIR/controlnet/ --enable-insecure-extension-access ${EXTRA_SD_FORGE_ARGS}" > $LOG_DIR/sd_forge.log 2>&1 &
  echo $! > /tmp/sd_forge.pid
fi


send_to_discord "Stable Diffusion Forge Started"

if env | grep -q "PAPERSPACE"; then
  send_to_discord "Link: https://$PAPERSPACE_FQDN/sd-forge/"
fi


if [[ -n "${CF_TOKEN}" ]]; then
  if [[ "$RUN_SCRIPT" != *"sd_forge"* ]]; then
    export RUN_SCRIPT="$RUN_SCRIPT,sd_forge"
  fi
  bash $current_dir/../cloudflare_reload.sh
fi

echo "### Done ###"