import json
import logging
import os
import sys

from web3 import Web3
from web3.auto import w3
from decimal import Decimal
from typing import Any, Dict, Optional, Tuple
from eth_account import Account, messages

def verify_txn_sig(msg):
    txn = msg['txn']
    sig = msg['sig']

    message = messages.encode_defunct(text=str(txn))
    rec_pubaddr = w3.eth.account.recover_message(message, signature=sig)
    print("from =", txn['from'])
    print("rec_pubaddr =", rec_pubaddr)

    assert(txn['from'] == rec_pubaddr)
    
def sig_test(filename, pubaddr, privkey):

    #acct = w3.eth.account.create('dkapd98fy7sd7dd')
    #print(acct.address)
    #print(acct.privateKey.hex())
    print(pubaddr)
    print(privkey)
     
    file = open(filename, 'r')
    txnfile = file.read()
    print("file:")
    print(txnfile)
    txnjson = json.loads(txnfile)
    print(f'json: {json.dumps(txnjson)}')

    txn = txnjson['txn']
    print(f'txn: {json.dumps(txn)}')

    #// This part prepares "version E" messages, using the EIP-191 standard
    message = messages.encode_defunct(text=str(txn))
    print("encoded message:\n", message)

    #// This part signs any EIP-191-valid message
    signed_message = Account.sign_message(message, private_key=privkey)
    print("signature =", signed_message.signature.hex())

    txnjson['sig'] = signed_message.signature

    verify_txn_sig(txnjson)



def main():
    print("sig test")
    args = sys.argv[1:]
    sig_test(args[0], args[1], args[2])

if __name__ == "__main__":
    main()



