{ pkgs, lib, config, inputs, ... }:

{
  # https://devenv.sh/basics/
  env.GREET = "devenv";

  # https://devenv.sh/packages/
  packages = 
    let
      podman_4_9 = import inputs.podman_4_9 { system = pkgs.stdenv.system; };
      officialpkgs = import inputs.officialpkgs { system = pkgs.stdenv.system; };
    in
      [
        pkgs.git
        officialpkgs.nodejs_22
        officialpkgs.elixir_1_18
        officialpkgs.erlang_27
        podman_4_9.podman
        officialpkgs.qemu
        officialpkgs.postgresql_15
        officialpkgs.wait4x
        officialpkgs.openssh
        officialpkgs.jq
      ];

  # https://devenv.sh/languages/
  # languages.rust.enable = true;

  # https://devenv.sh/processes/
  # processes.cargo-watch.exec = "cargo-watch";
  processes.postgresql = {
    exec = ''
      podman -c devenv run -e POSTGRES_PASSWORD=postgres --rm -p 5434:5432 --name dpulc_db postgres:15
      '';

    process-compose = {
      shutdown = {
        command = "podman stop dpulc_db";
      };
    };
  };

  processes.figgy_db = {
    exec = ''
      podman -c devenv run -e POSTGRES_PASSWORD=postgres --rm --name dpulc_figgy_db -p 5435:5432 ghcr.io/pulibrary/dpul-collections:figgy-fixtures
      '';

    process-compose = {
      shutdown = {
        command = "podman stop dpulc_figgy_db";
      };
    };
  };

  processes.test_solr = {
    exec = ''
      podman -c devenv run --rm --name dpulc_test_solr -p 8984:8983 -v /mnt/$(pwd):/app pulibrary/ci-solr:8.4-v1.0.0 bin/solr -cloud -noprompt -f -p 8983
      '';

    process-compose = {
      shutdown = {
        command = "podman stop dpulc_test_solr";
      };
    };
  };

  processes.dev_solr = {
    exec = ''
      podman -c devenv run --rm --name dpulc_dev_solr -p 8985:8983 -v /mnt/$(pwd):/app pulibrary/ci-solr:8.4-v1.0.0 bin/solr -cloud -noprompt -f -p 8983
      '';

    process-compose = {
      shutdown = {
        command = "podman stop dpulc_dev_solr";
      };
    };
  };

  # https://devenv.sh/services/
  # services.postgres.enable = true;

  # https://devenv.sh/scripts/
  scripts.setup = {
    exec = ''
      devenv tasks run app:setup
    '';
    binary = "bash";
    description = "Prepare everything";
  };

  scripts.tests = {
    exec = ''
      setup
      mix test
    '';
    binary = "bash";
    description = "Run tests";
  };

  scripts.poweroff = {
    exec = ''
      devenv processes down > /dev/null 2>&1 || true
      podman machine stop devenv > /dev/null 2>&1 || true
      echo "Boomshakalaka"
    '';
  };

  scripts.clean = {
    exec = ''
      poweroff
      podman machine rm devenv -y > /dev/null 2>&1 || true
      echo "All services stopped & deleted"
    '';
  };

  tasks = {
    "app:setup" = {
      exec = ''
        wait4x -q -t 5m tcp localhost:5434 localhost:5435
        mix deps.get
        mix setup
        MIX_ENV=test mix setup
      '';
      after = [ "processes:setup_solr" ];
    };
    "processes:setup_solr" = {
      after = ["processes:start"];
    };
    "processes:setup_dev_solr" = {
      exec = ''
        wait4x -q -t 5m tcp localhost:8985
        podman -c devenv exec --user root dpulc_dev_solr /bin/bash -c 'apt-get update -y && apt-get install -y zip' || true
        podman -c devenv exec dpulc_dev_solr /app/bin/setup_solr.sh || true
      '';
      status = ''
        output=$(wait4x -q -t 1s http http://solr:SolrRocks@localhost:8985/solr/dpulc/admin/ping --expect-status-code 200)
      '';
      after = ["processes:setup_solr"];
    };
    "processes:setup_test_solr" = {
      exec = ''
        wait4x -q -t 5m tcp localhost:8984
        podman -c devenv exec --user root dpulc_test_solr /bin/bash -c 'apt-get update -y && apt-get install -y zip' || true
        podman -c devenv exec dpulc_test_solr /app/bin/setup_solr.sh || true
      '';
      status = ''
        output=$(wait4x -q -t 1s http http://solr:SolrRocks@localhost:8984/solr/dpulc/admin/ping --expect-status-code 200)
      '';
      after = ["processes:setup_solr"];
        # podman -c devenv exec --user root dpulc_dev_solr /bin/bash -c 'apt-get update -y && apt-get install -y zip' || true
        # podman -c devenv exec dpulc_dev_solr /app/bin/setup_solr.sh || true
    };
    "processes:start" = {
      exec = ''
        devenv processes up -d
      '';
      status = ''
        output=$(wait4x -q -t 1s tcp localhost:8984 localhost:8985)
      '';
      after = [ "podman:start" ];
    };
    "podman:init" = {
      exec = ''
        podman machine init -m 8192 -v $HOME:/mnt/$HOME devenv
        '';
      status = ''
        output=$(podman machine list --format json | jq '.[] | select(.Name=="devenv")' -e)
      '';
      before = [ "podman:start" ];
    };
    "podman:start" = {
      exec = ''
        podman machine start devenv
        '';
      status = ''
        output=$(podman machine list --format json | jq '.[] | select(.Name=="devenv").Running' -e)
        '';
    };
  };

  enterShell = ''
    git --version
  '';

  # https://devenv.sh/tasks/
  # tasks = {
  #   "myproj:setup".exec = "mytool build";
  #   "devenv:enterShell".after = [ "myproj:setup" ];
  # };

  # https://devenv.sh/tests/
  enterTest = ''
    echo "Running tests"
    git --version | grep --color=auto "${pkgs.git.version}"
  '';

  # https://devenv.sh/git-hooks/
  # git-hooks.hooks.shellcheck.enable = true;

  # See full reference at https://devenv.sh/reference/options/
}
