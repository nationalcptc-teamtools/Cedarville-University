Nano is a terminal text editor. It can edit configuration files such as host mappings and resolver settings.

```bash
nano notes.txt
sudo nano /etc/hosts
```

- **Ctrl+O**, then **Enter:** Save the file.
- **Ctrl+X:** Exit.

Use elevated privileges only when the file requires them. DNS-related configuration paths depend on the system's resolver software; `/etc/resolv-dnsmasq` applies to a particular dnsmasq configuration rather than every Linux installation.
