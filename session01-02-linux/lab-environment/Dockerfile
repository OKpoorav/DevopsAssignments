FROM ubuntu:22.04
ENV DEBIAN_FRONTEND=noninteractive
RUN apt-get update && apt-get install -y systemd systemd-sysv nginx cron iproute2 iputils-ping dnsutils traceroute curl wget net-tools netcat-openbsd telnet tcpdump procps less file tree sudo adduser lsof iputils-tracepath mtr-tiny whois nano vim-tiny && apt-get clean && rm -rf /var/lib/apt/lists/*
RUN systemctl mask getty.target console-getty.service systemd-logind.service
STOPSIGNAL SIGRTMIN+3
CMD ["/sbin/init"]
