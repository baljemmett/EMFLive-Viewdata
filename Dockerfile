FROM verity.microwavepizza.co.uk/telstar:latest
LABEL maintainer="Ben A L Jemmett <emflive@microwavepizza.co.uk>"

RUN apt-get -y update \
        && apt-get -y install \
        libtext-wrapper-perl \
        libtext-unidecode-perl \
        && rm -rf /var/lib/apt/lists/*

COPY ./lib /opt/telstar/lib/
COPY ./guestbook ./render-guestbook ./sign-guestbook ./telstar-util /opt/telstar/
