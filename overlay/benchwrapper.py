import os
import re
import signal
import subprocess
import sys

test_cpus = int(sys.argv[1])
commands_to_run = sys.argv[2:]


def call_systemctl(args):
    return subprocess.check_output(["systemctl"] + args).decode()


def call_systemd_run(args):
    p = subprocess.Popen(["systemd-run"] + args)
    p.communicate()


def get_allowed_cpus():
    allowed_cpus = set()
    search_res = re.search(
        "AllowedCPUs=(.*)", call_systemctl(["show", "system.slice"])
    )
    # Check if AllowedCPUs is present
    if search_res is None:
        allowed_cpus = set(range(0, os.cpu_count()))
    else:
        allowed_cpus_text = search_res.group(1)
        for cpu_group in allowed_cpus_text.split(" "):
            # Either a CPU range
            if "-" in cpu_group:
                cpu_range_low, cpu_range_high = cpu_group.split("-")
                for cpu in range(int(cpu_range_low), int(cpu_range_high) + 1):
                    allowed_cpus.add(int(cpu))
            # or a single index
            else:
                allowed_cpus.add(int(cpu_group))
    return allowed_cpus


def set_system_cpus(cpus):
    system_cpus_range = " ".join(map(str, sorted(cpus)))
    call_systemctl(
        [
            "set-property",
            "--runtime",
            "system.slice",
            f"AllowedCPUs={system_cpus_range}",
        ]
    )
    call_systemctl(
        [
            "set-property",
            "--runtime",
            "user.slice",
            f"AllowedCPUs={system_cpus_range}"
        ]
    )


def cleanup(task_cpus):
    allowed_cpus = get_allowed_cpus()
    new_allowed_cpus = allowed_cpus.union(task_cpus)
    set_system_cpus(new_allowed_cpus)
    return


def handle_interrupt(signum, frame):
    print("Gracefully benchmark interrupting")
    cleanup(task_cpus)
    sys.exit(0)


allowed_cpus = get_allowed_cpus()

reserved_cpus = os.cpu_count() - len(allowed_cpus)
if (reserved_cpus + test_cpus) * 2 > os.cpu_count():
    print(
        "'benchwrapper' invocations may use at most half of CPUs. "
        f"{os.cpu_count() - len(allowed_cpus)} "
        f"CPUs out of {os.cpu_count()} are currently used"
        ", please wait for other invocations to finish or "
        "or request less CPUs"
    )
    sys.exit(1)
# Taking 'test_cpus' from the allowed set
task_cpus = set(sorted(allowed_cpus)[-1:-test_cpus - 1:-1])
new_system_cpus = allowed_cpus.difference(task_cpus)

# Call cleanup on SIGTERM and SIGHUP
signal.signal(signal.SIGTERM, handle_interrupt)
signal.signal(signal.SIGHUP, handle_interrupt)

try:
    set_system_cpus(new_system_cpus)
    task_cpus_range = " ".join(map(str, sorted(task_cpus)))
    call_systemd_run(
        [
            "--nice=-20",
            "--slice",
            "shield",
            "-EPATH=$PATH",
            f"--property=AllowedCPUs={task_cpus_range}",
            "--pty",
            "--same-dir",
            "--collect",
            "--",
        ]
        + commands_to_run
    )
finally:
    cleanup(task_cpus)
