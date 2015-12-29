{% import_yaml "subversion/defaults.yaml" as defaults %}

{% for docker_name in salt['pillar.get']('subversion:dockers', {}) %}
{% set docker = salt['pillar.get']('subversion:dockers:' ~ docker_name,
                                   default=defaults.docker, merge=True) %}

{% set docker_binds = [] %}
{% set docker_envs = {} %}
{% set docker_links = [] %}
{% if 'repos' in docker %}
  {% do docker_binds.append(docker.repos ~ ':' ~ docker.docker_repos) %}
{% endif %}

{% if 'basic' in docker %}
{% do docker.update({'apache_conf':'/srv/svn/docker/' ~ docker_name ~ '/apache_svn.conf'}) %}
{% do docker_binds.append(docker.apache_conf ~ ':' ~ docker.docker_apache_conf) %}
{% set basic = salt['pillar.get']('subversion:dockers:' ~ docker_name ~ ':basic', 
                                         default=defaults.basic, merge=True) %}

subversion-docker_{{ docker_name }}-apache-conf:
  file.managed:
    - name: {{ docker.apache_conf }}
    - makedirs: True
    - source: salt://subversion/templates/apache_svn_basic.conf
    - template: jinja
    - defaults:
        path: {{ basic.path }}
        {% if 'access' in basic %}
        {% do docker_binds.append(basic.access ~ ':' ~ basic.docker_access) %}
        access: {{ basic.docker_access }}
        {% endif %}
        {% if 'users' in basic %}
        {% do docker_binds.append(basic.users ~ ':' ~ basic.docker_users) %}
        users: {{ basic.docker_users }}
        {% endif %}
        svn_repos: {{ docker.docker_repos }}
    - watch_in:
      - dockerng: {{ docker_name }}
{% endif %}

{% if 'redmine' in docker %}
  {% set db = docker.redmine.database %}
  {% do docker_envs.update({'REDMINE_DB_NAME':db.name, 'REDMINE_DB_USER':db.user, 'REDMINE_DB_PASS':db.pass}) %}
  {% do docker_envs.update({'REDMINE_DB_ADAPTER':db.adapter}) %}
  {% if 'docker' in db %}
    {% do docker_links.append(db.docker ~ ':' ~ db.adapter)%}
  {% endif %}
{% endif %}

{% set image = docker.image if ':' in docker.image else docker.image ~ ':latest' %}
subversion-docker-running_{{ docker_name }}:
  dockerng.running:
    - name: {{ docker_name }}
    - image: {{ image }}
    - ports:
      - {{ docker.docker_http_port }}
    - binds:
      {% for bind in docker_binds %}
      - {{ bind }}
      {% endfor%}
    - environment:
      {% for env_name, env_val in docker_envs.items() %}
      - {{ env_name }}: {{ env_val }}
      {% endfor %}
    {% if docker_links %}
    - links:
      {% for link in docker_links %}
      - {{ link }}
      {% endfor %}
    {% endif %}

subversion-docker_{{ docker_name }}_image_{{ image }}:
  cmd.run:
    - name: docker pull {{ image }}
    - unless: '[ $(docker images -q {{ image }}) ]'
    - require_in:
      - dockerng: {{ docker_name }}
{% endfor %}
