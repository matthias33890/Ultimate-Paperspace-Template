#!/bin/bash
current_dir=$(dirname "$(realpath "$0")")
if ! [ -e "/tmp/sd-webui.prepared" ]; then
    bash $SCRIPT_ROOT_DIR/utils/discord/send.sh "Preparing Environment for Stable Diffusion WebUI"
    # Install Python 3.10
    apt-get install -y python3.10 python3.10-venv
    python3.10 -m venv /tmp/sd-webui-env
    source /tmp/sd-webui-env/bin/activate

    pip install --upgrade pip
    pip install --upgrade wheel setuptools
    pip install requests gdown bs4
    pip uninstall -y torch torchvision torchaudio protobuf lxml
    
    bash prepare_repo.sh
    export PYTHONPATH="$PYTHONPATH:$WEBUI_DIR"
    # must run inside webui dir since env['PYTHONPATH'] = os.path.abspath(".") existing in launch.py
    cd $WEBUI_DIR
    python $current_dir/preinstall.py
    cd $current_dir

    if [ -n "${ACTIVATE_XFORMERS}" ]; then
        pip install xformers==0.0.16
    fi

    touch /tmp/sd-webui.prepared
else
    source /tmp/sd-webui-env/bin/activate
fi

bash $SCRIPT_ROOT_DIR/utils/discord/send.sh "Downloading Models"
bash $SCRIPT_ROOT_DIR/utils/model_download/main.sh
bash $SCRIPT_ROOT_DIR/utils/discord/send.sh "Finished Downloading Models"

python $SCRIPT_ROOT_DIR/utils/model_download/link_model.py

bash start.sh
bash $SCRIPT_ROOT_DIR/utils/discord/send.sh "Stable Diffusion WebUI Started"