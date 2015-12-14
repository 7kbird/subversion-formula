{% import_yaml "subversion/defaults.yaml" as defaults %}

{% for docker_name in salt['pillar.get']('subversion:dockers', {}) %}
{% set docker = salt['pillar.get']('subversion:dockers:' ~ docker_name,
                                   default=defaults.docker, merge=True) %}
{% do docker.update({'apache_conf':'/srv/svn/docker/' ~ docker_name ~ '/apache_svn.conf'}) %}
{% set docker_binds = [docker.apache_conf ~ ':' ~ docker.docker_apache_conf,
                       docker.repos ~ ':' ~ docker.docker_repos] %}

{% if 'basic' in docker %}
{% set basic = salt['pillar.get']('subversion:dockers:' ~ docker_name ~ ':basic', 
                                         default=defaults.basic, merge=True) %}

subversion-docker_{{ docker_name }}-apache-conf:
  file.managed:
    - name: {{ docker.apache_conf }}
    - makedirs: True
    - source: salt://subversion/templates/apache_svn_basic.conf
    - template: jinja
    - defaults:
        path: {{ docker.docker_path }}
        {% if 'access' in basic %}
        {% do docker_binds.append(basic.access ~ ':' ~ basic.docker_access) %}
        access: {{ basic.docker_access }}
        {% endif %}
        {% if 'users' in basic %}
        {% do docker_binds.append(basic.users ~ ':' ~ basic.docker_users) %}
        users: {{ basic.docker_users }}
        {% endif %}
        svn_repos: {{ docker.docker_repos }}
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
    - require:
      - file: {{ docker.apache_conf }}

subversion-docker_{{ docker_name }}_image_{{ image }}:
  cmd.run:
    - name: docker pull {{ image }}
    - unless: '[ $(docker images -q {{ image }}) ]'
    - require_in:
      - dockerng: {{ docker_name }}
{% endfor %}
