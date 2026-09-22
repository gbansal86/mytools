# Third-party software and attribution

## Nuditag

This wrapper depends on the separate open-source project:

**ICIJ / Nuditag**  
https://github.com/ICIJ/nuditag

Upstream project metadata identifies Nuditag as MIT-licensed.

The setup script currently pins:

~~~text
f34134341b62cb320ac299e60335d432f19d6ebf
~~~

The Nuditag source itself is **not copied into this repository**. 01_Setup_Nuditag_On_E.bat downloads the pinned upstream source archive from GitHub and installs it into the local Python virtual environment.

## Python

The setup script downloads the official Windows 64-bit Python 3.12.10 installer from:

https://www.python.org/

Python is a separate third-party project with its own license and terms.

## Model and Python dependencies

Nuditag manages its own Python dependencies and model requirements. At the pinned upstream revision, its classifier references:

~~~text
ICIJ/nsfw-image-detection-384-onnx
~~~

through the Hugging Face Hub client.

Refer to the upstream Nuditag repository and model repository for their current licensing, provenance, and documentation.

## This wrapper

The BAT, Python, and PowerShell wrapper files in this folder are convenience automation around the upstream software. They should not be mistaken for the upstream Nuditag project or an official ICIJ distribution.
