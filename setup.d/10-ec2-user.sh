#!/usr/bin/env bash

id ec2-user > /dev/null 2>&1 && userdel -r ec2-user
id rocky > /dev/null 2>&1 && userdel -r rocky
