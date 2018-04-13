#!/bin/bash
# Clean up the yum cache - found to be necessary when upgrading from one minor release to another ...

yum clean all
rm -rf /var/cache/yum
