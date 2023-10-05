# Building your own Blackbox

<!-- Most Hush Line users should follow [**this documentation**](https://scidsg.github.io/hushline-docs/book/intro.html). If you'd really like to set up your own Blackbox Hush Line, read and follow the instructions in this document. -->

## Required Hardware

- **Hardware:** [Raspberry Pi 4](https://www.amazon.com/Raspberry-Model-2019-Quad-Bluetooth/dp/B07TC2BK1X/?&_encoding=UTF8&tag=scidsg-20&linkCode=ur2&linkId=ee402e41cd98b8767ed54b1531ed1666&camp=1789&creative=9325)/[3B+](https://www.amazon.com/ELEMENT-Element14-Raspberry-Pi-Motherboard/dp/B07P4LSDYV/?&_encoding=UTF8&tag=scidsg-20&linkCode=ur2&linkId=d76c1db453c42244fe465c9c56601303&camp=1789&creative=9325)
- **Power:** [Raspberry Pi USB-C Power Supply](https://www.amazon.com/Raspberry-Pi-USB-C-Power-Supply/dp/B07W8XHMJZ?crid=20ZD3IB2N877C&keywords=raspberry%2Bpi%2Bpower%2Bsupply&qid=1696270477&sprefix=raspberry%2Bpi%2Bpower%2B%2Caps%2C140&sr=8-5&th=1&linkCode=ll1&tag=scidsg-20&linkId=fa55eb4c089361952be8285bf67bfd22&language=en_US&ref_=as_li_ss_tl)
- **Storage:** [Micro SD Card](https://www.amazon.com/Sandisk-Ultra-Micro-UHS-I-Adapter/dp/B073K14CVB?crid=1XCUWSKV8V2L1&keywords=microSD+card&qid=1696270565&sprefix=microsd+car%2Caps%2C137&sr=8-21&linkCode=ll1&tag=scidsg-20&linkId=a2865a28ae852876a5a6d27512e9d7ef&language=en_US&ref_=as_li_ss_tl)
- **SD Card Adapter:** [SD Card Reader](https://www.amazon.com/SanDisk-MobileMate-microSD-Card-Reader/dp/B07G5JV2B5?crid=3ESM9TOJBH8J7&keywords=microsd+card+adaptor+usb+sandisk&qid=1696270641&sprefix=microsd+card+adaptor+usb+sandisk%2Caps%2C135&sr=8-3&linkCode=ll1&tag=scidsg-20&linkId=90d3bed4e490d29d84bcf86d9fe75290&language=en_US&ref_=as_li_ss_tl) 
- **e-ink Screen:** [Waveshare 2.7inch E-Ink Display](https://www.amazon.com/2-7inch-HAT-Resolution-Electronic-Communicating/dp/B075FQKSZ9/?_encoding=UTF8&pd_rd_w=hNy2N&content-id=amzn1.sym.5f7e0a27-49c0-47d3-80b2-fd9271d863ca%3Aamzn1.symc.e5c80209-769f-4ade-a325-2eaec14b8e0e&pf_rd_p=5f7e0a27-49c0-47d3-80b2-fd9271d863ca&pf_rd_r=KQ1ZCPA2Q08D1SW2GYJH&pd_rd_wg=mepbv&pd_rd_r=e97f3e03-7e7d-4165-84e8-3face81f7190&ref_=pd_gw_ci_mcx_mr_hp_atf_m)
- _Affiliate links_

You'll also need a separate computer which you'll use to decrypt and view Blackbox messages.

## Procedure

**Step 1**: Download Raspberry Pi Imager from [https://www.raspberrypi.com/software/](https://www.raspberrypi.com/software/)

**Step 2**: Insert microSD and prepare to flash Raspberry Pi OS. 
* Choose OS > Raspberry Pi OS (other) > Raspberry Pi OS (64-Bit).
* Select the location of your microSD card.
* BEFORE you click "Write", click the gear button in the corner. 
Enter these settings:
    * Hostname = `blackbox`
    * Choose to Enable SSH with password authentication
    * User = `box`
    * Set a strong password
    * Enter your wireless (LAN) settings if your Pi will use wifi to connect to the internet
    * Set your local timezone

**Step 3**: Now click "Write". This will take a moment to complete.

**Step 4**: When the Pi Imager program is done writing, unplug your microSD card from your computer.

**Step 5**: On the back of your Waveshare e-ink display, note which "Rev" it is: e.g. 2.1 or 2.2.

**Step 6**: Plug MicroSD card in to your Pi. With the power cable NOT plugged in, plug in e-ink screen. Now plug the power cable into the outlet. Your Pi should boot up.

**Step 7**: Wait about 3 minutes for your Pi to boot up.

**Step 8**: Back on viewing computer, run `ssh box@blackbox.local`. 

(If you get an error that `ssh: Could not resolve hostname blackbox.local: Name or service not known`, that likely just means that your Pi is still booting up and connecting to your wifi network. Wait a few minutes, and then try again.)

**Step 9**: If it was successful, you'll see something like:
```
$ ssh box@blackbox.local
The authenticity of host 'blackbox.local (192.168.X.XX)' can't be established.
ED25519 key fingerprint is SHA256: <fingerprint>
This key is not known by any other names
Are you sure you want to continue connecting (yes/no/[fingerprint])? 
```

Type `yes` and hit enter.

You'll then be asked to enter "`box@blackbox.local`'s password". Enter the password you created in step 2 (tip: If you need to paste your password, use `command+shift+v`).

If you enter your password correctly, you'll see a message like this:
```text
Linux blackbox 6.1.21-v8+ #1642 SMP PREEMPT Mon Apr  3 17:24:16 BST 2023 aarch64

The programs included with the Debian GNU/Linux system are free software;
the exact distribution terms for each program are described in the
individual files in /usr/share/doc/*/copyright.

Debian GNU/Linux comes with ABSOLUTELY NO WARRANTY, to the extent
permitted by applicable law.
Last login: Tue May  2 23:23:49 2023
box@blackbox:~ $ 
```

**Step 10**: 

Next, if your e-ink display is `Rev2.1`, run:
```bash
curl -sSL https://raw.githubusercontent.com/scidsg/blackbox/main/v1/helper.sh | sudo bash
```

If your e-ink display is `Rev2.2`, run:
```bash
curl -sSL https://raw.githubusercontent.com/scidsg/blackbox/main/v2/helper.sh | sudo bash
```

<!-- **Step 10b**: After some programs install, you may be asked to enter your Pi's username. If so, delete the default username (`Pi`) and enter `box` instead. -->

**Step 11**: Next, in the Raspberry Pi configuration menu, arrow down to "Interface Options". In that sub-menu, choose to enable SPI interface.

After enabling SPI, you'll be returned to the Raspberry Pi configuration menu. Use tab to navigate to the `<Finish>` option. Hit enter.

Wait a few minutes for some more software to be installed on the Pi.

**Step 12**: Once all programs are installed, and you see `box@blackbox:~ $` again, reboot Pi by running `sudo reboot` or unplugging your Pi and then plugging it in again.

**Step 13**: After your Pi boots up again it will finish installing Blackbox, which may take a few minutes. When it's finished, a QR code will appear on the e-ink screen. This QR code leads to [https://blackbox.local/setup](https://blackbox.local/setup), where you'll configure your Blackbox.

**Step 14**: Over on viewing computer, open [https://blackbox.local/setup](https://blackbox.local/setup) in a browser (ignore security warnings by clicking "Advanced" -> "Accept the Risk and continue"). Fill out form with your Blackbox email address information (we strongly recommend creating a new email account for Blackbox to use -- Gmail works well. See [this documentation for instructions](https://scidsg.github.io/blackbox-docs/book/prereqs/general.html#2-gmail)).

Note: If you're using [Mailvelope](https://mailvelope.com/en/) to generate a new PGP key-pair, you'll need to export (save) your public key as a file, and then manually upload this public key file to [keys.openpgp.org.](https://keys.openpgp.org/) Do NOT upload your private PGP key!

**Step 15**: Once who've completely filled out this form, hit submit. In a few minutes, you should receive a confirmation email, which, among other things, contains your Blackbox URL. 

**Step 16**: Share your new Blackbox URL with your community, along with instructions on how to [download and install the Tor Browser](https://www.torproject.org/download/). 

If your community faces [a higher threat](https://scidsg.github.io/hushline-docs/book/prereqs/threat-modeling.html), recommend to them that they better protect their anonymity by only visiting your Blackbox URL on personal devices while using a public WiFi network. [Read more about threat modeling here.](https://scidsg.github.io/hushline-docs/book/prereqs/threat-modeling.html)

<!-- ## How to check the status of your Blackbox from the command line -->

<!-- ``` -->
<!-- systemctl status blackbox-installer.service -->
<!-- ``` -->

## Reference
[https://scidsg.github.io/hushline-docs/book/prereqs/raspberrypi.html](https://scidsg.github.io/hushline-docs/book/prereqs/raspberrypi.html)

[https://www.raspberrypi.com/documentation/computers/remote-access.html](https://www.raspberrypi.com/documentation/computers/remote-access.html)


