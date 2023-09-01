---
layout: post
title: "Why you should keep files inside your VM"
date: 2023-08-28
---
_Update (2023-09-01)_: This article has also been [posted on HN](https://news.ycombinator.com/item?id=37343274).

I should perhaps clarify my specific use case here. I'm running a local VM for web development and I use the VM to isolate the various development tools. My threat model assumes that I trust the guest – this means that sandbox escape is not a security concern of mine.

Some commenters have pointed out VirtioFS. This is a valid option that I have not yet explored. However, I always give preference to solutions that work out of the box and don't require installing additional support software on the host which is why VirtioFS is a no-go for me on Windows. I'm not using Windows for development at this time but my goal is to have a general approach that could work across different hosts. Currently this means sharing directories via NFS on Unix-y hosts and using Samba on Windows.

---

If you're virtualizing your development environments with VMs then you're probably aware that there are plenty of ways to share your project files with the virtual machine. You probably also know that if you're working with non trivial projects, pretty much all of those methods have shortcomings.

This article is based on my experiences with Vagrant over the years (and, more recently, Multipass) but it can easily apply to other virtualization tools which utilise the file sharing/syncing methods mentioned below.

### File _sharing_ vs _syncing_

I make a distinction between file sharing and syncing in this article. File _sharing_ is a way to make your files visible to the VM without copying them to the native filesystem inside the VM whereas file _syncing_ is just that - a way of copying files over and making sure that the file state is the same on both the source and the destination.

### The problem with host-to-VM file sharing/syncing

I've tried multiple ways of sharing or syncing files from the host to the VM, such as NFS, Samba, Rsync, SSHFS and the Virtualbox shared folder driver. Eventually I've found that all of them leave a lot to be desired. The main issues are the following:

- **Performance.** The impact of this can vary but it tends to get worse the bigger your project is. If you're running a Linux VM on a Unix-y host, you'll probably find that NFS works rather well but it's still not native-level performance.
- **Compatibility issues.** If you can somehow live with the performance issues (e. g. your project is not very IO heavy), the compatibility problems are what's really going to wear you down in the end. 

  Most file sharing methods will require you to set up file permission and owner masks which is not ideal because you lose granular control. Additionally, depending on your chosen sharing method, you also lose out on filesystem events - the host is no longer aware of file changes inside the VM via the [inotify API](https://man7.org/linux/man-pages/man7/inotify.7.html) (Samba [seems to have support](https://lwn.net/Articles/896055/) for this though). You can also forget about setting up [Linux ACLs](https://www.redhat.com/sysadmin/linux-access-control-lists) if your use case requires this (this can technically be overcome with a driver-specific ACL mechanism but this is hardly a saving grace, see the following point). Symlinks are also not an option anymore if you go this route.

  No matter which method you choose, you're most probably sacrificing features and/or performance or introduce...
- **...complexity.** This shouldn't come as a surprise but any file sharing or syncing mechanism will inevitably introduce some level of complexity into your workflow. Even if your preferred method works 99% of the time, the remaining 1% will eat up your time and will cause friction. The ultimate goal here is to minimize it as much as possible.

    The issue of complexity becomes especially apparent if you need your VM setup to work across multiple host operating systems. While you might figure something out for Unix-based hosts, God forbid if you also need your setup to work on Windows. Good luck!

#### A note on file syncing

**Rsync** deserves a special mention here (well, not Rsync in particular, but any file syncing method really). As a file _syncing_ method, it eliminates the first two problems mentioned above but whatever it saves you in performance and compatibility, it takes away with added complexity. The complexity is twofold:

1. **You become responsible for syncing files.** You can watch file changes on the host and have those files automatically synced with the VM (just like Vagrant does with its `vagrant rsync-auto` command) but this quickly falls apart when either you or your application makes changes _inside the VM_ and you need to sync them back to the host. This introduces a risk of unintentionally overwriting files during automatic sync from the host to the VM or leads to issue no. 2:
2. **Increased cognitive load.** You're now suddenly responsible for keeping track of file state changes inside and outside the VM. This alone makes file syncing impractical in my workflows. The importance of this cannot be understated - virtualization should make your work easier and more streamlined, not add unwanted complexity to something as basic as file writes.

### The solution

The solution to most of the problems above seems obvious to me: **keep your files inside the VM!** Despite a couple of slight disadvantages, this nets you loads of benefits:

- **Native performance.** No comment necessary here.
- **Great compatibility.** Since all of your project files are stored on a native filesystem, you don't have to compromise on features. No need to force file masks, map UIDs or deal with weird driver-specific shenanigans like [this SSHFS mount issue I've experienced some time ago](https://github.com/canonical/multipass/issues/2369). There can be all sorts of unexpected problems that come from that specific file sharing method X and this is simply not something you'll want to compromise on.
- **Isolation.** A nice side benefit of storing all of your files inside the VM is that all of your project files now live in the VM. This may feel unnatural at first but it actually makes sense. After all, your development environment is in a VM so why should your project files be exempt from this? If you're worried about losing access to your files in case of a VM breakdown, this is actually less of a problem than it seems at first glance - if you're following best practices, you should be committing and pushing your code to a VCS regularly anyway*. The only real downside of this approach is an operational one: you can only access your files while the VM is running. Depending on your setup, this can be a non-issue though.

_\*Of course, in this case you'll lose all uncommited files (such as a database, for example). In any case, if this is a concern, you should have some backup measures in place anyway and should not rely on a VM to keep your files intact._

### Accessing files inside the VM from your host

Instead of sharing your files with the guest VM, you should consider storing them in the VM's native file system and sharing them with the host (i. e. the host is acting as a client here). This is somewhat similar to what [WSL2 does with the 9P file server](https://devblogs.microsoft.com/commandline/whats-new-for-wsl-in-windows-10-version-1903/#how-it-works) and can be achieved with pretty much any file server that you prefer. I use NFS because it's trivial to set up on the guest and just as easy to mount on the host.

The only downside of this approach that I can see is reduced file IO performance on the host which should be tolerable in most cases. If you're using something like PhpStorm, your IDE may take a little longer to index your project if it accesses it on a mounted network share but such IO-heavy operations are usually not done very often and it's therefore a small price to pay for the benefits of being able to run your application on a native file system along with all other advantages this entails. And if you're using VSCode, there are remote development extensions that will allow you to view your files directly in the editor via SSH so there's no need for manual mounting.

This feels like the most robust setup I've tried because the responsibility of sharing your files is not offloaded to the host. Generally, if you're working with VMs you'll probably want to isolate as much as possible inside the VM to reduce friction when setting up VMs on different hosts. File sharing and networking are usually the two main pain points of working with VMs for me, with the latter one being the lesser of the two.
