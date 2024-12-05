external_url 'http://gitlab.local:8080'
nginx['listen_port'] = 8080
nginx['redirect_http_to_https'] = false
nginx['ssl_certificate'] = nil
nginx['ssl_certificate_key'] = nil
gitlab_rails['gitlab_shell_ssh_port'] = 22
unicorn['worker_processes'] = 2
postgresql['shared_buffers'] = "256MB"
postgresql['max_worker_processes'] = 4 