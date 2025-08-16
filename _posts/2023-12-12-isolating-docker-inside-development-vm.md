---
layout: post
title: "Isolating Docker inside a development VM"
date: 2023-12-12
---

_Update (2025-05-11)_: Docker v28 has [introduced](https://www.docker.com/blog/docker-engine-28-hardening-container-networking-by-default/) significant changes to container security by default.

While it's great that Docker is aiming for a more hardened out of the box experience, my personal stance on this remains unchanged – I would still choose to contain Docker inside a VM whenever possible. As has also been [remarked by others](https://github.com/moby/moby/issues/22054#issuecomment-2854488866), this is mostly because there's far less complexity and cognitive overhead involved in spinning up a VM when compared to installing complex software directly on the host. I prefer to treat any tool that messes with my firewall directly as something to be contained rather than implicitly trusted to do the right thing. It helps that I have structured my entire workflow around virtualization over the years, too.

---

One of the biggest gotchas that I've experienced when using Docker was how it handles the firewall rules. Apparently, if you’ve set your `iptables` firewall up to deny incoming connections you might be less than pleasantly surprised to find out that Docker actually _modifies your `iptables` rules and exposes your containers to other hosts on the same network_.

**Note:** I should clarify that I am definitely not an expert on Docker or Unix networking in general. However, based on my findings which I detail below, I can easily reproduce the issue and my suggested solution should be reasonably effective (provided your environment allows encapsulating Docker inside a VM, of course).

## Reproducing the problem

I've used Multipass with the QEMU driver on a macOS host to reproduce the issue in question. The steps outlined below are based on [this comment](https://github.com/moby/moby/issues/22054#issuecomment-962202433) on an issue in the `moby/moby` repo.

First, launch two virtual machines. I'll call them `victim` and `attacker`:

```
multipass launch --name victim docker
multipass launch --name attacker
```

The victim in this scenario will be the one running Docker containers so I've used an Ubuntu image that comes with Docker preinstalled. Both machines can ping each other because they're on the same internal network. In this scenario, they will simulate two devices connected to the same local network.

Next, shell into the victim's machine and run the following commands:

```
ufw enable
ufw allow ssh
docker run -p 127.0.0.1:8080:80 -d nginx
```

This will enable the firewall and run an Nginx container that binds its 80 port to port 8080 on the loopback interface.

Now login to the attacker's machine and create the following routing rule:

```
ip route add 172.16.0.0/12 via <IP_of_victims_vm>
```

Assuming that the Nginx container is reachable via `172.17.0.2` inside the victim's VM, you can now reach the Nginx welcome page from the attacker's VM with `curl 172.17.0.2`. The above routing rule will route all packets intended for the `172.16.0.0/12` subnet via the victim's machine due to a routing rule that Docker creates in the `iptables` firewall of the victim's VM.

## Origins of the problem

This is not a new issue. It's actually a collection of problems that have been documented and talked about an inordinate number of times. Here's just a sample of tickets related to this issue:

- <https://github.com/moby/moby/issues/14041>
- <https://github.com/moby/moby/issues/22054>
- <https://github.com/moby/moby/discussions/45524> (contains a list of additional links)
- <https://github.com/moby/moby/issues/45610>

Some of these are actually separate problems related to how Docker handles routing but they all have one thing in common: they introduce unexpected side effects on the Docker host.

Even more surprising is the fact that the issue reproduced in the previous section seems to have no viable solution at the moment, at least in my opinion. I say no _viable_ solution because there are plenty of workarounds out there but most that I've seen involve nauseating levels of tinkering with `iptables` rules directly.

While this might work in certain cases, I found this to be completely impractical when setting up a local development environment because it's simply too brittle. Your setup might break with the next Docker update and you will be forced to review your custom `iptables` configuration in case something starts behaving unexpectedly.

What else can we do besides replacing Docker altogether?

## Isolating Docker

An alternative solution to this problem is isolating Docker inside a VM which is only accessible to the host. Yes, I know - running a VM has its downsides but bear with me.

This way you can let Docker have its way with `iptables` rules inside the VM without the need to set up additional rules yourself. With this setup, Docker never touches the firewall rules of the host and therefore it should not be possible to route packets directly to a Docker container from outside the host that's running the VM.

It's critical to note that this would only work if your VM is not accessible via the local network. Such access would be possible if you've set up a custom network configuration for the VM for example, such as a bridged network interface to expose the VM on the local network.

I was rather surprised to find out that this wasn't much talked about. This was the most straightforward solution for me to adopt because I was already heavily invested in VM-based development environments. It provides the following benefits:

- **Prevents Docker from botching your host's firewall.** I tend to isolate trigger-happy software that I'm not comfortable with running on my host and Docker seems to feel a little too comfortable with modifying my firewall.
- **It's a more stable and sustainable solution.** It reduces the risk of Docker's internal changes breaking your firewall setup since you're not intervening in how Docker manages the firewall of the VM at all.
- **All Docker-managed network interfaces are isolated.** It reduces the risk of Docker clashing with whatever network configuration you have on the VM host.

Honestly, I just don't care about the internals of Docker enough to warrant browsing through countless discussion threads in search of a working solution that monkeypatches the firewall to prevent the vulnerability discussed above. Even if Docker fixes this issue completely, this is still complex software that does complex things, and running such software in a VM provides numerous aforementioned benefits.

## A note on managing complexity

Obviously the VM solution suggested above is not ideal for all use cases. My preferred workflow is to have a VM per project so it's a no-brainer for me to spin up a new VM and isolate all (or most - whichever is more practical) development dependencies in it but it may not be the case for you.

This might not be obvious at first but even though a VM introduces technical as well as cognitive overhead, it provides a considerable benefit, too: it **encapsulates complexity**. If a Docker engine update breaks your project, this breakage is contained to a single project and does not affect your other VMs, not to mention the actual host that is running these machines. Other software running on your host does not interact with Docker directly (and vice versa) so the risk of different software interacting with each other in unexpected ways is reduced as well.

And because development VMs are often disposable (unless you use them in a non-disposable way), if everything else fails you still have the nuclear solution at hand – you can always destroy the VM and spin up a new one in its place. This is not quite possible if you're running a single Docker instance on the same Linux host that you run your other applications in. The latter setup is the equivalent of holding all of your eggs in one basket. It's brittle and tightly coupled; a single OS update can break things with no easy rollback strategy.

In short, a VM isolates your development dependencies as much as it encapsulates their complexity in a more controlled environment that is decoupled from the rest of the host. The curious case of Docker discussed above is an example of how a VM could help with isolating software that can be tricky to configure properly.