class Glooctl < Formula
  desc "Envoy-Powered API Gateway"
  homepage "https://docs.solo.io/gloo/latest/"
  # NOTE: Please wait until the newest stable release is finished building and
  # no longer marked as "Pre-release" before creating a PR for a new version.
  url "https://github.com/solo-io/gloo.git",
      tag:      "v1.11.8",
      revision: "5a5fe0df44155baabb283f4c777802680b03fd97"
  license "Apache-2.0"
  head "https://github.com/solo-io/gloo.git", branch: "master"

  livecheck do
    url :stable
    regex(/^v?(\d+(?:\.\d+)+)$/i)
  end

  bottle do
    sha256 cellar: :any_skip_relocation, arm64_monterey: "ca6e5bbd6dfd9f56d662b935b53e95a015db7ae94a5df718c590d814c3436de8"
    sha256 cellar: :any_skip_relocation, arm64_big_sur:  "11cc3803f9b70120fd1c7570e59ce9dca76b43d123f917a38f18b127cd0c2f26"
    sha256 cellar: :any_skip_relocation, monterey:       "b1455c276eef977701db0da6c4108c28aa89d52fdf7dddf086d677efb3d21476"
    sha256 cellar: :any_skip_relocation, big_sur:        "0dbf83e8d3e7e8b62b0b01b2ac2df8891f333a07b6b1eedc3f1d7fce60dd7360"
    sha256 cellar: :any_skip_relocation, catalina:       "2c67aae8241c9d6e23418e73f631afbcf5ef3e19fbc264c791e2cf31f3bff329"
    sha256 cellar: :any_skip_relocation, x86_64_linux:   "ee486761efee9c4f614ee44b9e00b248838a853542ceb8c6ed8ecf9ec5bca864"
  end

  depends_on "go" => :build

  def install
    system "make", "glooctl", "TAGGED_VERSION=v#{version}"
    bin.install "_output/glooctl"
  end

  test do
    run_output = shell_output("#{bin}/glooctl 2>&1")
    assert_match "glooctl is the unified CLI for Gloo.", run_output

    version_output = shell_output("#{bin}/glooctl version 2>&1")
    assert_match "Client: {\"version\":\"#{version}\"}", version_output

    version_output = shell_output("#{bin}/glooctl version 2>&1")
    assert_match "Server: version undefined", version_output

    # Should error out as it needs access to a Kubernetes cluster to operate correctly
    status_output = shell_output("#{bin}/glooctl get proxy 2>&1", 1)
    assert_match "failed to create kube client", status_output
  end
end
