<div align="center">

# transpire

Nix-based Kubernetes management

</div>

> [!IMPORTANT]  
> Transpire is a work in progress. See the [roadmap](#roadmap) for more details.

Transpire is a Kubernetes configuration management framework for Nix. It brings the flexibility of the NixOS module system to Kubernetes, enabling version-controlled, reproducible, and scalable infrastructure management.

This project is designed with everything I learned building and running [transpire v1](https://github.com/ocf/transpire) with my friends at the UC Berkeley Open Computing Facility. Transpire for Nix aims to supersede transpire v1 at the OCF, while also being flexible enough to use anywhere.

## Usage

For now, only flakes are supported. Transpire exports a function `lib.<system>.build.cluster` which generates a derivation that builds a folder of YAML manifests for each namespace based on your modules:

```nix
{
  inputs.transpire.url = "github:oliver-ni/transpire";

  outputs = { transpire, ... }: {
    packages.x86_64-linux.default = transpire.lib.x86_64-linux.build.cluster {
      modules = [ ./cluster.nix ];
    };
  };
}
```

Also, see `lib.<system>.evalModules`, `lib.<system>.build`, and `lib.<system>.build.clusterFile`.

See the [example](./example/) for a more complex configuration.

## Roadmap

Transpire is a work in progress! Here's what I'm working on:

- [x] Basic options for directly converting Nix manifests to YAML
- [x] Fetching and templating Helm charts
- [x] Generating typed options based on Kubernetes OpenAPI spec
- [ ] Converting between lists indexed by `name` and attribute sets
- [ ] Built-in modules and functions for simple use cases
- [ ] A better secrets story
