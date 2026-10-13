# reference fix (not imported; used by scripts/check_scenarios.py)
export LC_ALL=C.UTF-8 LANG=C.UTF-8 HOME=/root
cat > /srv/ansible/hardening.yml <<'YML'
- name: Server hardening
  hosts: localhost
  connection: local
  tasks:
    - name: SSH hardening settings
      ansible.builtin.copy:
        dest: /etc/ssh/sshd_config.d/50-hardening.conf
        content: |
          MaxAuthTries 3
          PermitRootLogin prohibit-password
          X11Forwarding no
        mode: "0600"
        validate: /usr/sbin/sshd -t -f %s
      notify: restart sshd

    - name: Deploy user
      ansible.builtin.user:
        name: deploy
        shell: /bin/bash
        create_home: true

    - name: Login banner
      ansible.builtin.copy:
        dest: /etc/issue.net
        content: "Authorized use only. Activity is logged.\n"
        mode: "0644"

  handlers:
    - name: restart sshd
      ansible.builtin.service:
        name: sshd
        state: restarted
YML
cd /srv/ansible && ansible-playbook hardening.yml </dev/null >/tmp/play.log 2>&1 || { tail -20 /tmp/play.log; exit 1; }
