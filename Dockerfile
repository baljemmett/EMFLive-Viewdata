FROM verity.microwavepizza.co.uk/telstar:latest
LABEL maintainer="Ben A L Jemmett <emflive@microwavepizza.co.uk>"

RUN apt-get -y update \
        && apt-get -y install \
        libmail-sendeasy-perl \
        libtext-wrapper-perl \
        libtext-unidecode-perl \
        libberkeleydb-perl \
        liblist-moreutils-xs-perl \
        liblist-moreutils-perl \
        libmodule-build-perl \
        make \
        && rm -rf /var/lib/apt/lists/* \
        && cpan -T install Search::Indexer \
        && rm -rf ~/.cpan

COPY ./lib /opt/telstar/lib/
COPY ./guestbook ./render-guestbook ./sign-guestbook ./search ./search-index.pl ./build-index.pl ./phone-search ./search-phonebook.pl ./ingest-schedule ./ingest-phonebook ./telstar-util /opt/telstar/
