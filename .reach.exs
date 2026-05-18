[
  layers: [
    mix_tasks: "Mix.Tasks.Xamal.*",
    orchestration: [
      "Xamal.Deployment",
      "Xamal.App",
      "Xamal.Build",
      "Xamal.Server",
      "Xamal.Lock",
      "Xamal.Prune",
      "Xamal.SecretTasks",
      "Xamal.Audit",
      "Xamal.Details",
      "Xamal.Remove",
      "Xamal.Versions"
    ],
    runtime: [
      "Xamal.BlueGreen",
      "Xamal.DeployLock",
      "Xamal.Hooks",
      "Xamal.Logs",
      "Xamal.Output",
      "Xamal.Remote",
      "Xamal.Shell",
      "Xamal.TaskHelpers"
    ],
    commands: "Xamal.Commands.*",
    configuration: "Xamal.Configuration.*",
    ssh: "Xamal.SSH.*"
  ],
  deps: [
    forbidden: [
      {:commands, :mix_tasks},
      {:commands, :orchestration},
      {:commands, :runtime},
      {:commands, :ssh},
      {:configuration, :mix_tasks},
      {:configuration, :orchestration},
      {:configuration, :runtime},
      {:configuration, :ssh},
      {:runtime, :mix_tasks},
      {:orchestration, :mix_tasks},
      {:ssh, :mix_tasks},
      {:ssh, :orchestration},
      {:ssh, :runtime}
    ]
  ],
  source: [
    forbidden_modules: ["Xamal.CLI", "Xamal.CLI.*"],
    forbidden_files: ["lib/xamal/cli/**"]
  ],
  calls: [
    forbidden: [
      {"Xamal.Commands.*", ["File.write", "File.write!", "Xamal.SSH.*"]},
      {"Mix.Tasks.Xamal.*", ["Xamal.Commands.*", "Xamal.SSH.*"]}
    ]
  ],
  smells: [
    fixed_shape_map: [
      min_keys: 3,
      min_occurrences: 3,
      evidence_limit: 10
    ],
    behaviour_candidate: [
      min_modules: 3,
      min_callbacks: 3,
      module_display_limit: 8,
      callback_display_limit: 8
    ]
  ]
]
