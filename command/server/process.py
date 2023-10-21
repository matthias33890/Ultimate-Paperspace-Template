import time
import requests
from db import db, Task
from sd_fooocus import process_t2i as fooocus_process
from share import *

import logging
logging.basicConfig(
    level=logging.INFO,
    format=log_format)


def wait_for_server_ready(url):
    while True:
        try:
            response = requests.get(url)
            if response.status_code == 200:
                return True
        except requests.exceptions.ConnectionError:
            pass
        time.sleep(1)
        


def process():
    logging.info("Start background process")
    # Assume only one process task, so restart all job on restart
    Task.update(status="Pending").where(Task.status == "Running").execute()
    while True:
        task = None
        with db.transaction():
            task = (
                Task.select()
                .where(Task.status == "Pending")
                .first()
            )
            if task:
                logging.info(f"Processing task {task.id}")
                task.status = "Running"
                task.save()
        if task:
            if task.task_type == "fooocus_t2i":
                try:
                    logging.info("Checking if server is ready")
                    wait_for_server_ready("http://localhost:7015")
                    logging.info("Server is ready")
                    fooocus_process(task)
                except:
                    #TODO retry
                    logging.exception("Encountered error during fooocus inference")
                    task.status = "Error"
                    task.save()
                
        time.sleep(1)

if __name__ == "__main__":
    process()

# TODO api for reading meta
# dirty workaround: read log in fooocus output folder, complete md5 with output image in gradio folder