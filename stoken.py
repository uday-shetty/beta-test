#!/usr/bin/env python

import os
import argparse
import sys
from azure.common.credentials import ServicePrincipalCredentials
from azure.mgmt.resource import ResourceManagementClient
from azure.mgmt.storage import StorageManagementClient
from azure.mgmt.compute import ComputeManagementClient
from azure.mgmt.storage.models import StorageAccountCreateParameters
from azure.storage.table import TableService, Entity

#SUB_ID = os.environ['ACCOUNT_ID']
#TENANT_ID = os.environ['TENANT_ID']
#RG_NAME = os.environ['GROUP_NAME']
#SA_NAME = os.environ['TOKEN_STORAGE_ACCOUNT']

#Azure Table Name to store Token
TBL_NAME = 'tokentable'

def get_key(SUB_ID, RG_NAME, SA_NAME, APP_ID, APP_SECRET, TENANT_ID):
    #global SUB_ID, TENANT_ID, RG_NAME, SA_NAME

    cred = ServicePrincipalCredentials(
        client_id=APP_ID,
        secret=APP_SECRET,
        tenant=TENANT_ID
    )

    #resource_client = ResourceManagementClient(cred, SUB_ID)
    storage_client = StorageManagementClient(cred, SUB_ID)

    storage_keys = storage_client.storage_accounts.list_keys(RG_NAME, SA_NAME)
    storage_keys = {v.key_name: v.value for v in storage_keys.keys}

    return storage_keys['key1']


def print_id(sa_key, SA_NAME):
    #global SA_NAME, TBL_NAME
    global TBL_NAME
    tbl_svc = TableService(account_name=SA_NAME, account_key=sa_key)
    if not tbl_svc.exists(TBL_NAME):
        return False
    try:
        tokenid = tbl_svc.get_entity(TBL_NAME, 'token', '1')
        print("{}".format(tokenid.token_ip))
	return True
    except:
        return False


def add_id(sub_id, rg_name, SA_NAME, manager_ip, AppId, AppSecret, TenantId):
    #global  TBL_NAME, SA_NAME
    global  TBL_NAME
    print("SUB ID{}".format(sub_id))
    print("RG_NAME{}".format(rg_name))
    print("SA_NAME{}".format(SA_NAME))
    print("MANAGER IP{}".format(manager_ip))
    print("App ID{}".format(AppId))
    print("App Secret {}".format(AppSecret))
    print("Tenant ID{}".format(TenantId))

    key = get_key(sub_id, rg_name, SA_NAME, AppId, AppSecret, TenantId)
    print("Key{}".format(key))

    create_table(key, SA_NAME )

    tbl_svc = TableService(account_name=SA_NAME, account_key=key)
    try:
        # this upsert operation should always succeed
    	token_id = {'PartitionKey': 'token', 'RowKey': '1', 'token_ip': manager_ip}
        tbl_svc.insert_or_replace_entity(TBL_NAME, token_id)
        print("successfully inserted/replaced token ID {}".format(id))
        return True
    except:
        print("exception while inserting Token ID")
        return False

def create_table(sa_key, SA_NAME):
    #global TBL_NAME, SA_NAME
    global TBL_NAME
    tbl_svc = TableService(account_name=SA_NAME, account_key=sa_key)
    try:
        # this will succeed only once for a given table name on a storage account
        tbl_svc.create_table(TBL_NAME, fail_on_exist=True)
        print("successfully created table")
        return True
    except:
        print("exception while creating table")
        return False

def main():

    parser = argparse.ArgumentParser(description='Tool to store Docker swarm token info in Azure Tables')
    subparsers = parser.add_subparsers(help='commands', dest='action')
    get_id_parser = subparsers.add_parser('get-id', help='Get Token info from table specified in env var TBL_NAME')
    get_id_parser.add_argument('id', help='key to the account')
    get_id_parser.add_argument('id1', help='Storage Account')
    add_id_parser = subparsers.add_parser('add-id', help='Insert Token to table specified in env var TBL_NAME')
    add_id_parser.add_argument('id1', help='SUB ID')
    add_id_parser.add_argument('id2', help='Resource Group name')
    add_id_parser.add_argument('id3', help='Storage account name')
    add_id_parser.add_argument('id4', help='manager IP')
    add_id_parser.add_argument('id5', help='APP ID')
    add_id_parser.add_argument('id6', help='APP Secret')
    add_id_parser.add_argument('id7', help='Tenant ID')

    args = parser.parse_args()

    #key=get_storage_key()

    if args.action == 'add-id':
        add_id(args.id1, args.id2, args.id3, args.id4, args.id5, args.id6, args.id7)
    elif args.action == 'get-id':
        print_id(args.id, args.id2)
    else:
        parser.print_usage()

if __name__ == "__main__":
    main()
