#!/bin/bash

if [ ! -e $STACKATO_FILESYSTEM/files ]; then
  mkdir -p $STACKATO_FILESYSTEM/files
  cp -r files/* $STACKATO_FILESYSTEM/files
fi

rm -rf files
ln -s $STACKATO_FILESYSTEM/files files

if [ ! -e $STACKATO_FILESYSTEM/backup ]; then
  mkdir -p $STACKATO_FILESYSTEM/backup
fi

ln -s $STACKATO_FILESYSTEM/backup backup
