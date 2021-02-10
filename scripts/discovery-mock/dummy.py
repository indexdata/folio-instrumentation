# finds 10 random instances and resolves all holdings and items every 5 minutes
import os
import logging
import random
import requests
import time

from math import ceil

OKAPI = os.environ['OKAPI']
USERNAME = os.environ['USERNAME']
PASSWORD = os.environ['PASSWORD']
TENANT = os.environ['TENANT']
MAX_DELAY = 120 # delay for each cycle is a random int between 1 and MAX_DELAY
FETCH = 50


def main():
    logging.basicConfig(
        format='%(asctime)s %(levelname)-8s %(message)s',
        level=logging.INFO,
        datefmt='%Y-%m-%d %H:%M:%S'
    )

    while True:
        current_delay = MAX_DELAY + random.randint(1, MAX_DELAY)
        token = get_token()
        record_indices = pick_instances(token, FETCH)
        for i in record_indices:
            instance = get_instance_by_index(token, i)
            logging.info("found instance {}".format(instance['id']))
            holdings = get_holdings_by_instance_id(token, instance['id'])
            for holding in holdings:
                logging.info("found holding {}".format(holding['id']))
                items = get_items_by_holdings_id(token, holding['id'])
                logging.info("found {} items".format(len(items['items'])))
        logging.info("sleeping for {} seconds".format(str(current_delay)))
        time.sleep(current_delay)

def get_token():
    headers = {"X-Okapi-Tenant": TENANT}
    payload = {
        "username" : USERNAME,
        "password" : PASSWORD
    }
    r = requests.post(OKAPI + '/authn/login',
                      headers=headers, json=payload)
    return r.headers['x-okapi-token']

def pick_instances(token, count):
    headers = {
        'x-okapi-tenant' : TENANT,
        'x-okapi-token': token
    }
    payload = {"limit": 0}
    r = requests.get(OKAPI + '/instance-storage/instances',
                     params=payload,
                     headers=headers)

    total_records = r.json()['totalRecords']
    record_indices = []
    for i in range(count):
        record_indices.append(random.randrange(0, total_records -1))

    return(record_indices)

def get_instance_by_index(token, index):
    headers = {
        'x-okapi-tenant' : TENANT,
        'x-okapi-token': token
    }
    r = requests.get(
            OKAPI + '/instance-storage/instances',
            params={'limit': 1, 'offset': index},
            headers=headers
        )
    return r.json()['instances'][0]

def get_holdings_by_instance_id(token, instance_id):
    headers = {
        'x-okapi-tenant' : TENANT,
        'x-okapi-token': token
    }
    payload = {
        'limit': 500,
        'query': 'instanceId=={}'.format(instance_id)
    }
    r = requests.get(OKAPI + '/holdings-storage/holdings',
    params=payload,
    headers=headers)
    return r.json()['holdingsRecords']

def get_items_by_holdings_id(token, holdings_id):
    headers = {
        'x-okapi-tenant' : TENANT,
        'x-okapi-token': token
    }
    payload = {
        'limit': 500,
        'query': 'holdingsRecordId=={}'.format(holdings_id)
    }
    r = requests.get(OKAPI + '/item-storage/items',
    params=payload,
    headers=headers)
    return r.json()

if __name__ == "__main__":
    main()
