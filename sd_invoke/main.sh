#!/bin/bash
set -e

current_dir=$(dirname "$(realpath "$0")")
cd $current_dir
source .env

# Set up a trap to call the error_exit function on ERR signal
trap 'error_exit "### ERROR ###"' ERR


echo "### Setting up Stable Diffusion InvokeAI ###"
log "Setting up Stable Diffusion InvokeAI"
if [[ "$REINSTALL_SD_INVOKE" || ! -f "/tmp/sd_invoke.prepared" ]]; then

    mkdir -p $DATA_DIR/sd_invoke_models
    mkdir -p $INVOKEAI_ROOT/models

    symlinks=(
      "$REPO_DIR/outputs:$IMAGE_OUTPUTS_DIR/stable-diffusion-invokeai"
      "$MODEL_DIR:$WORKING_DIR/models"
      "$MODEL_DIR/sd:$LINK_MODEL_TO"
      "$MODEL_DIR/lora:$LINK_LORA_TO"
      "$MODEL_DIR/controlnet:$LINK_CONTROLNET_TO"
      "$MODEL_DIR/embedding:$LINK_EMBEDDING_TO"
      "$MODEL_DIR/vae:$LINK_VAE_TO"
      "$DATA_DIR/sd_invoke_models:$INVOKEAI_ROOT/models"
    )
    prepare_link "${symlinks[@]}"
    rm -rf $VENV_DIR/sd_invoke-env
    
    
    python3.10 -m venv $VENV_DIR/sd_invoke-env
    
    source $VENV_DIR/sd_invoke-env/bin/activate

    pip install pip==24.0
    pip install --upgrade wheel setuptools
    
    apt-get install -qq build-essential -y > /dev/null
    apt-get install -qq python3-opencv libopencv-dev -y > /dev/null
    pip install pypatchmatch

    pip install "InvokeAI[xformers]" --use-pep517
    invokeai-configure -y --skip-sd-weights
    
    touch /tmp/sd_invoke.prepared
else
    
    source $VENV_DIR/sd_invoke-env/bin/activate
    
fi
log "Finished Preparing Environment for Stable Diffusion InvokeAI"


if [[ -z "$SKIP_MODEL_DOWNLOAD" ]]; then
  echo "### Downloading Model for Stable Diffusion InvokeAI ###"
  log "Downloading Model for Stable Diffusion InvokeAI"
  bash $current_dir/../utils/sd_model_download/main.sh
  log "Finished Downloading Models for Stable Diffusion InvokeAI"
else
  log "Skipping Model Download for Stable Diffusion InvokeAI"
fi




if [[ -z "$INSTALL_ONLY" ]]; then
  echo "### Starting Stable Diffusion InvokeAI ###"
  log "Starting Stable Diffusion InvokeAI"
  cd "$REPO_DIR"
  PYTHONUNBUFFERED=1 service_loop "invokeai-web --port $SD_INVOKE_PORT \
  --autoimport_dir $REPO_DIR/autoimport/main \
  --lora_dir $REPO_DIR/autoimport/lora \
  --embedding_dir $REPO_DIR/autoimport/embedding \
  --controlnet_dir $REPO_DIR/autoimport/controlnet \
  ${EXTRA_SD_INVOKE_ARGS}" > $LOG_DIR/sd_invoke.log 2>&1 &
  echo $! > /tmp/sd_invoke.pid
fi


send_to_discord "Stable Diffusion InvokeAI Started"

if env | grep -q "PAPERSPACE"; then
  send_to_discord "Link: https://$PAPERSPACE_FQDN/sd-invoke/"
fi


if [[ -n "${CF_TOKEN}" ]]; then
  if [[ "$RUN_SCRIPT" != *"sd_invoke"* ]]; then
    export RUN_SCRIPT="$RUN_SCRIPT,sd_invoke"
  fi
  bash $current_dir/../cloudflare_reload.sh
fi

echo "### Done ###"