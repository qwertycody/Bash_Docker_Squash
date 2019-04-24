# bash-docker-squash
A Docker Squash Alternative that uses no external dependencies and works completely using Built-in Bash/Docker functionality.

The problem
-----------

As previously stated on https://github.com/goldmann/docker-squash/blob/master/README.rst

Docker creates many layers while building the image. Sometimes it's not necessary or desireable
to have them in the image. For example a Dockerfile `ADD` instruction creates a single layer
with files you want to make available in the image. The problem arises when these files are
only temporary files (for example product distribution that you want to unpack). Docker will
carry this unnecessary layer always with the image, even if you delete these files in next
layer. This a waste of time (more data to push/load/save) and resources (bigger image).

Squashing helps with organizing images in logical layers. Instead of
having an image with multiple (in almost all cases) unnecessary layers -
we can control the structure of the image.

Features
--------

- Can squash all layers layers from an image
- Squashed image can be loaded back to the Docker daemon or stored as tar archive somewhere
- Automatically detects and generates the corresponding Dockerfile using "docker inspect" parsing

Usage
--------

1. Download the squash.sh bash script
2. Before running make sure you have at least 2-3 times the size freespace on the HD of the image you are trying to squash
3. In GitBash/Cygwin or Linux do "sh squash.sh"
4. Wait a bit
5. Delete Container and Create new container based off new base image - maybe do house keeping on old images

Troubleshooting
--------

- It should be relatively understood that this is a roughly put together hack (may not work 100% of the time) and that you may end up having issues with Dynamic Dockerfile Generation. If this IS the case you can supplement the functionality in the Build Function with the actual original Dockerfile.
