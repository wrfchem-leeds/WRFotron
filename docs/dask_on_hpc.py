#!/usr/bin/env python3
import os
import sys
import numpy as np
import dask.bag as db
from dask_jobqueue import SGECluster
from dask.distributed import Client
import joblib

nums = np.random.randint(low=0, high=100, size=(5_000_000))


def weird_function(nums):
    return chr(nums)


def main():
    # dask cluster and client
    number_processes = 1
    number_jobs = 35
    number_workers = number_processes * number_jobs

    cluster = SGECluster(
        interface="ib0",
        walltime="04:00:00",
        memory=f"2 G",
        resource_spec=f"h_vmem=2G",
        scheduler_options={
            "dashboard_address": ":2727",
        },
        job_extra=[
            "-cwd",
            "-V",
            f"-pe smp {number_processes}",
            f"-l disk=1G",
        ],
        local_directory=os.sep.join([os.environ.get("PWD"), "dask-worker-space"]),
    )

    client = Client(cluster)
    cluster.scale(jobs=number_jobs)

    # main processing
    print("processing ...")
    results = []
    bag = db.from_sequence(nums, npartitions=number_workers)
    results = bag.map(weird_function).compute()

    print("saving ...")
    joblib.dump(results, f"/nobackup/${USER}/results.joblib")

    client.close()
    cluster.close()


if __name__ == "__main__":
    main()
