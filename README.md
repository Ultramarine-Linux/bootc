# Ultramarine Linux - atomic bootc experiment

> [!NOTE]
> This is an experimental version of Ultramarine Linux, based on the new [bootc](https://github.com/containers/bootc) project.
> Do not expect it to be stable or usable for anything other than testing. You have been warned.
>
> Supercedes [Ultramarine-Linux/ostree](https://github.com/Ultramarine-linux/ostree).

Experimental version of Ultramarine Linux, based on bootc.

## Notes on building derivatives

If you would like to build a derivative of Ultramarine Linux (also called a "Shade" in Ultramarine parlance), you should append this to the end of your Containerfile (for now):

```Dockerfile
# HACK: workaround for imagectl rechunk expecting RPM database in rpm-ostree images
# we don't use rpm-ostree, but upstream expects it
# 
# The `.` here is to ensure that copies still work when the directories still exist
RUN cp -av /usr/lib/sysimage/rpm/. /usr/share/rpm/.
```

This is a temporary workaround for an issue in `imagectl rechunk` that expects an RPM database to be present in the image. Since bootc images do not use rpm-ostree, we manually copy the RPM database to the expected location.

