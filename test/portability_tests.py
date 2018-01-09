"""Script to run portability tests.

Assumes there's a json file somewhere that defines the tests to run.
"""
import argparse
import datetime
import json
import os
import time

import requests


class PortabilityTestsFailed(Exception):

    """A special exeception for a portability test failure."""
    pass


def get_parser():
    """Get the ArgumentParser for the script."""
    parser = argparse.ArgumentParser()
    parser.add_argument("--portability_tests_json")
    return parser


def print_test_states(test_states):
    """Print the states of tests. Use capital letters to look authoritative.

    Also, note that travis requires that you echo something every so ofter or it
    thinks your job has frozen.
    """
    print("{:%Y-%m-%dT%H:%M:%SZ}".format(datetime.datetime.utcnow()), flush=True)
    for test_name, test_state in test_states.items():
        print("TEST:{} STATE:{}".format(test_name, test_state), flush=True)


def main():
    """Read the tests to run, submit them to the service, and wait for them to complete.

    If everything doesn't succeed, fail.
    """
    parser = get_parser()
    args = parser.parse_args()

    with open(args.portability_tests_json) as test_json:
        test_definition = json.load(test_json)

    service_url = test_definition["portability_service_url"]

    # The portability json defines headers the we expect to see defined as
    # environment variables. This lets us stick them encrypted into travis
    service_headers = {h[1]: os.environ[h[0]]
                       for h in test_definition["portability_service_headers"]}

    test_ids = {}

    # Launch all tests
    for test in test_definition["portability_tests"]:

        print("SUBMITTING TEST {}".format(test["name"]), flush=True)
        dependency_wdls = []
        for depencency_wdl in test.get("dependency_wdls", []):

            name = os.path.basename(depencency_wdl)
            code = open(depencency_wdl).read()

            dependency_wdls.append({
                "name": name,
                "code": code
            })

        workflow_descriptor = open(test["portability_wdl"]).read()
        workflow_params = open(test["portability_inputs"]).read()

        post_data = {
            "workflow_descriptor": workflow_descriptor,
            "workflow_params": workflow_params
        }

        if dependency_wdls:
            post_data["workflow_dependencies"] = dependency_wdls

        response = requests.post(
            os.path.join(service_url, "portability_tests"),
            headers=service_headers,
            json=post_data)

        print("STATUS RESPONSE FROM SERVICE FOR TEST {}".format(test["name"]), flush=True)
        print(json.dumps(json.loads(response.text), indent=4), flush=True)

        test_id = json.loads(response.text)["test_id"]

        test_ids[test["name"]] = test_id

    # I don't really know what happens if you ask for the status of a test that
    # isn't finished submitting, but I bet it's not good. So wait a little bit.
    time.sleep(30)

    # Now we play the waiting game
    # We'll iterate over all tests we submitted, and once they've all reached a
    # terminal state, we'll halt and decide whether exit cleanly or raise.
    terminal_tests = {}
    while True:
        test_states = {}
        for test_name, test_id in test_ids.items():

            if test_name in terminal_tests:
                test_states[test_name] = terminal_tests[test_name]
                continue

            response = requests.get(
                os.path.join(
                    service_url, "portability_tests", test_id, "status"),
                headers=service_headers)

            test_state = json.loads(response.text)["state"]
            test_states[test_name] = test_state

        print_test_states(test_states)

        for test_name, test_state in test_states.items():
            if test_state in ("Failed", "Succeeded"):
                terminal_tests[test_name] = test_state

        if len(terminal_tests) == len(test_ids):
            break

        time.sleep(120)

    print_test_states(terminal_tests)
    print('\n', flush=True)

    if not all(k == "Succeeded" for k in terminal_tests.values()):
        raise PortabilityTestsFailed()

if __name__ == '__main__':
    main()
