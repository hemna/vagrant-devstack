#!/bin/bash

git clone http://github.com/Lokaltog/powerline
cd powerline
pip install --user .
cd ..

# download and install powerline fonts
wget --quiet https://github.com/Lokaltog/powerline/raw/develop/font/PowerlineSymbols.otf https://github.com/Lokaltog/powerline/raw/develop/font/10-powerline-symbols.conf
mkdir -p ~/.fonts/ && mv PowerlineSymbols.otf ~/.fonts/
fc-cache -vf ~/.fonts
mkdir -p ~/.config/fontconfig/conf.d/ && mv 10-powerline-symbols.conf ~/.config/fontconfig/conf.d/


# Add settings to make git branches show up in bash
mkdir -p ~/.config/powerline
cp -R ~/.local/lib/python2.7/site-packages/powerline/config_files/* ~/.config/powerline

# have to edit ~/.config/powerline/config.json
# and set the shell theme to 'default_leftonly'
cp /vagrant/files/home/.config/powerline/config.json ~/.config/powerline


cat >> ~/.bashrc<<-BASHRC
if [ -d "$HOME/.local/bin" ]; then
    PATH="$HOME/.local/bin:$PATH"
fi

if [ -f ~/.local/lib/python2.7/site-packages/powerline/bindings/bash/powerline.sh ]; then
    source ~/.local/lib/python2.7/site-packages/powerline/bindings/bash/powerline.sh
fi
BASHRC
