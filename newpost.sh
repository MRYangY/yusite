#!/bin/bash

echo "start create new post!!"

read -p "Enter post title:" title

echo "title is ${title}!"

hugo new posts/${title}.md

marktext content/posts/${title}.md


