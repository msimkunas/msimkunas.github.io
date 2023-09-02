---
layout: post
title: "PhpStorm path mapping configuration for remote Docker containers"
date: 2023-09-02
---

My usual web development workflow involves running Docker containers inside a local VM. This setup requires specific path mapping configuration in PhpStorm in order for PHPUnit and Xdebug to work properly.

In the `Settings | PHP` window, click the folder icon next to the `Docker container` row. In the new window that pops up, add a new path configuration under the `Volume bindings` section. The host path should be the path to your project files *on the VM* whereas the container path is the path your code is mounted at inside the Docker container.

Back at the PHP settings window, click the folder icon next to the `Path mappings` row. Add a new path configuration, only in this case set the local path to the path of your project files on your host that runs the VM and the remote path to the container path.

An example setup:

![PhpStorm path mapping configuration example](/assets/images/phpstorm-configuration-example.png)

In the above screenshot, `/Users/mantas/Projects/example` is the path of the project on the host that runs the VM, `/home/ubuntu/example` is the path inside the VM and `/var/ww/app` is the path the files are mounted at inside the Docker container.