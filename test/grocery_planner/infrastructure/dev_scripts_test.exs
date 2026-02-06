defmodule GroceryPlanner.Infrastructure.DevScriptsTest do
  use ExUnit.Case, async: true

  @bin_path Path.join([File.cwd!(), "bin"])
  @dev_script Path.join(@bin_path, "dev")
  @dev_full_script Path.join(@bin_path, "dev-full")
  @test_integration_script Path.join(@bin_path, "test-integration")

  describe "bin/dev script" do
    test "exists and is executable" do
      assert File.exists?(@dev_script), "bin/dev script not found"

      stat = File.stat!(@dev_script)
      # Check if owner has execute permission (bit 6 in mode)
      assert Bitwise.band(stat.mode, 0o100) != 0, "bin/dev is not executable"
    end

    test "has proper shebang" do
      first_line = File.stream!(@dev_script) |> Enum.take(1) |> List.first()
      assert String.starts_with?(first_line, "#!/"), "bin/dev missing shebang"
      assert first_line =~ "bash", "bin/dev should use bash"
    end

    test "uses proper error handling (set -e)" do
      content = File.read!(@dev_script)
      assert content =~ "set -e", "bin/dev should use 'set -e' for error handling"
    end

    test "starts only postgres and python-service (not elixir-app)" do
      content = File.read!(@dev_script)

      # Should start postgres and python-service
      assert content =~ "docker compose up -d postgres python-service",
             "bin/dev should start postgres and python-service"

      # Should NOT start all services or elixir-app explicitly
      refute content =~ ~r/docker compose up -d$/m,
             "bin/dev should not start all services"

      refute content =~ "docker compose up -d elixir-app",
             "bin/dev should not start elixir-app in Docker"

      # Should start Elixir locally
      assert content =~ "iex -S mix phx.server",
             "bin/dev should start Elixir locally with iex"
    end

    test "waits for python-service health check" do
      content = File.read!(@dev_script)

      assert content =~ "curl", "bin/dev should use curl to check health"
      assert content =~ "localhost:8000/health", "bin/dev should check Python service health"
      assert content =~ "MAX_ATTEMPTS", "bin/dev should have retry logic"
    end

    test "includes helpful output messages" do
      content = File.read!(@dev_script)

      assert content =~ ~r/echo.*Starting/i, "bin/dev should print starting message"
      assert content =~ ~r/echo.*ready/i, "bin/dev should print ready message"
      assert content =~ "localhost:4000", "bin/dev should mention Phoenix URL"
    end
  end

  describe "bin/dev-full script" do
    test "exists and is executable" do
      assert File.exists?(@dev_full_script), "bin/dev-full script not found"

      stat = File.stat!(@dev_full_script)
      assert Bitwise.band(stat.mode, 0o100) != 0, "bin/dev-full is not executable"
    end

    test "has proper shebang" do
      first_line = File.stream!(@dev_full_script) |> Enum.take(1) |> List.first()
      assert String.starts_with?(first_line, "#!/"), "bin/dev-full missing shebang"
      assert first_line =~ "bash", "bin/dev-full should use bash"
    end

    test "uses proper error handling (set -e)" do
      content = File.read!(@dev_full_script)
      assert content =~ "set -e", "bin/dev-full should use 'set -e' for error handling"
    end

    test "starts all services including elixir-app" do
      content = File.read!(@dev_full_script)

      # Should start all services with no arguments
      assert content =~ ~r/docker compose up -d$/m,
             "bin/dev-full should start all services"

      # Should NOT start only specific services
      refute content =~ "docker compose up -d postgres python-service",
             "bin/dev-full should not start only postgres and python-service"
    end

    test "includes service URLs in output" do
      content = File.read!(@dev_full_script)

      assert content =~ "localhost:4000", "bin/dev-full should mention Phoenix URL"
      assert content =~ "localhost:8000", "bin/dev-full should mention Python service URL"
      assert content =~ "localhost:5432", "bin/dev-full should mention Postgres port"
    end

    test "provides helpful commands for managing services" do
      content = File.read!(@dev_full_script)

      assert content =~ "docker compose logs", "bin/dev-full should mention logs command"
      assert content =~ "docker compose down", "bin/dev-full should mention down command"
    end
  end

  describe "bin/test-integration script" do
    test "exists and is executable" do
      assert File.exists?(@test_integration_script), "bin/test-integration script not found"

      stat = File.stat!(@test_integration_script)

      assert Bitwise.band(stat.mode, 0o100) != 0,
             "bin/test-integration is not executable"
    end

    test "has proper shebang" do
      first_line = File.stream!(@test_integration_script) |> Enum.take(1) |> List.first()
      assert String.starts_with?(first_line, "#!/"), "bin/test-integration missing shebang"
      assert first_line =~ "bash", "bin/test-integration should use bash"
    end

    test "uses proper error handling (set -e)" do
      content = File.read!(@test_integration_script)

      assert content =~ "set -e",
             "bin/test-integration should use 'set -e' for error handling"
    end

    test "starts dependencies before running tests" do
      content = File.read!(@test_integration_script)

      # Should start postgres and python-service
      assert content =~ "docker compose up -d postgres python-service",
             "bin/test-integration should start dependencies"

      # Order matters: start services, then run tests
      lines = String.split(content, "\n")
      docker_line = Enum.find_index(lines, &(&1 =~ "docker compose up"))
      test_line = Enum.find_index(lines, &(&1 =~ "mix test"))

      assert docker_line < test_line,
             "bin/test-integration should start services before running tests"
    end

    test "waits for python-service health check before running tests" do
      content = File.read!(@test_integration_script)

      assert content =~ "curl", "bin/test-integration should use curl to check health"

      assert content =~ "localhost:8000/health",
             "bin/test-integration should check Python service health"

      assert content =~ "MAX_ATTEMPTS", "bin/test-integration should have retry logic"

      # Health check should come before test run - check for the "until curl" pattern
      # The curl is in a loop structure, so we need to find "until curl" or the curl line itself
      lines = String.split(content, "\n")
      health_line = Enum.find_index(lines, &(&1 =~ ~r/curl.*8000.*health/))
      test_line = Enum.find_index(lines, &(&1 =~ ~r/^mix test/))

      assert health_line != nil, "Could not find health check line"
      assert test_line != nil, "Could not find test line"

      assert health_line < test_line,
             "bin/test-integration should check health before running tests"
    end

    test "runs integration tests with correct flags" do
      content = File.read!(@test_integration_script)

      assert content =~ "mix test", "bin/test-integration should run mix test"

      assert content =~ "--include integration",
             "bin/test-integration should include integration tag"
    end

    test "stops services after tests complete" do
      content = File.read!(@test_integration_script)

      assert content =~ "docker compose down",
             "bin/test-integration should stop services after tests"

      # The script has docker compose down in multiple places (error handling and cleanup)
      # We verify there's at least one after the test run
      lines = String.split(content, "\n")
      test_line = Enum.find_index(lines, &(&1 =~ ~r/^mix test/))

      # Find all down_line occurrences
      down_lines =
        lines
        |> Enum.with_index()
        |> Enum.filter(fn {line, _idx} -> line =~ "docker compose down" end)
        |> Enum.map(fn {_line, idx} -> idx end)

      # At least one docker compose down should come after the test
      assert Enum.any?(down_lines, &(&1 > test_line)),
             "bin/test-integration should stop services after running tests"
    end

    test "captures and exits with test exit code" do
      content = File.read!(@test_integration_script)

      # Should capture test exit code
      assert content =~ ~r/TEST_EXIT=\$/m,
             "bin/test-integration should capture test exit code"

      # Should exit with captured code
      assert content =~ ~r/exit \$TEST_EXIT/m,
             "bin/test-integration should exit with test result"

      # Order: run tests, capture exit, stop services, then exit
      lines = String.split(content, "\n")
      test_line = Enum.find_index(lines, &(&1 =~ ~r/^mix test/))
      capture_line = Enum.find_index(lines, &(&1 =~ "TEST_EXIT="))
      exit_line = Enum.find_index(lines, &(&1 =~ ~r/^exit \$TEST_EXIT/))

      # Find the final docker compose down (after tests, not the error handling one)
      down_lines =
        lines
        |> Enum.with_index()
        |> Enum.filter(fn {line, _idx} -> line =~ "docker compose down" end)
        |> Enum.map(fn {_line, idx} -> idx end)

      final_down_line = Enum.max(down_lines)

      assert test_line < capture_line,
             "should capture exit code after running tests"

      assert capture_line < final_down_line,
             "should capture exit code before final service stop"

      assert final_down_line < exit_line, "should exit after stopping services"
    end

    test "handles service startup failure gracefully" do
      content = File.read!(@test_integration_script)

      # Should have error handling for service startup
      assert content =~ ~r/if.*MAX_ATTEMPTS/s,
             "bin/test-integration should handle startup timeout"

      assert content =~ "docker compose logs",
             "bin/test-integration should show logs on failure"

      assert content =~ ~r/exit 1/m,
             "bin/test-integration should exit with error code on startup failure"
    end
  end

  describe "script consistency" do
    test "all scripts use the same health check approach" do
      dev_content = File.read!(@dev_script)
      test_content = File.read!(@test_integration_script)

      # Both should use curl to localhost:8000/health
      assert dev_content =~ "curl" and test_content =~ "curl",
             "both scripts should use curl"

      assert dev_content =~ "localhost:8000/health" and test_content =~ "localhost:8000/health",
             "both scripts should check the same health endpoint"

      # Both should have retry logic
      assert dev_content =~ "MAX_ATTEMPTS" and test_content =~ "MAX_ATTEMPTS",
             "both scripts should have retry logic"
    end

    test "all scripts use consistent Docker Compose commands" do
      dev_content = File.read!(@dev_script)
      dev_full_content = File.read!(@dev_full_script)
      test_content = File.read!(@test_integration_script)

      # All should use 'docker compose' (not 'docker-compose')
      assert dev_content =~ "docker compose", "bin/dev should use 'docker compose'"

      assert dev_full_content =~ "docker compose",
             "bin/dev-full should use 'docker compose'"

      assert test_content =~ "docker compose",
             "bin/test-integration should use 'docker compose'"

      # None should use old docker-compose syntax
      refute dev_content =~ "docker-compose",
             "bin/dev should not use old 'docker-compose' syntax"

      refute dev_full_content =~ "docker-compose",
             "bin/dev-full should not use old 'docker-compose' syntax"

      refute test_content =~ "docker-compose",
             "bin/test-integration should not use old 'docker-compose' syntax"
    end

    test "scripts that start services use -d flag for detached mode" do
      dev_content = File.read!(@dev_script)
      dev_full_content = File.read!(@dev_full_script)
      test_content = File.read!(@test_integration_script)

      # All should use -d flag to run in detached mode
      assert dev_content =~ "docker compose up -d",
             "bin/dev should use detached mode"

      assert dev_full_content =~ "docker compose up -d",
             "bin/dev-full should use detached mode"

      assert test_content =~ "docker compose up -d",
             "bin/test-integration should use detached mode"
    end
  end
end
