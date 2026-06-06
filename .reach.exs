[
  layers: [
    mix_tasks: "Mix.Tasks.Xamal.*",
    task_support: [
      "Xamal.CommandOptions",
      "Xamal.ConfigPrinter",
      "Xamal.Docs",
      "Xamal.Init",
      "Xamal.MixTask"
    ],
    orchestration: [
      "Xamal.Deployment",
      "Xamal.*Tasks",
      "Xamal.Audit",
      "Xamal.Details",
      "Xamal.Prune",
      "Xamal.Remove",
      "Xamal.Versions"
    ],
    runtime: [
      "Xamal.BlueGreen",
      "Xamal.Context",
      "Xamal.DeployLock",
      "Xamal.HealthCheck",
      "Xamal.Hooks",
      "Xamal.LocalIdentity",
      "Xamal.Logs",
      "Xamal.Output",
      "Xamal.Remote",
      "Xamal.Secrets.Adapters.*",
      "Xamal.TaskHelpers"
    ],
    commands: "Xamal.Commands.*",
    core: [
      "Xamal.EnvFile",
      "Xamal.Secrets",
      "Xamal.Utils"
    ],
    configuration: ["Xamal.Configuration", "Xamal.Configuration.*"],
    ssh: ["Xamal.SSH", "Xamal.SSH.*"]
  ],
  deps: [
    forbidden: [
      {:commands, :mix_tasks},
      {:commands, :orchestration},
      {:commands, :runtime},
      {:commands, :ssh},
      {:commands, :task_support},
      {:configuration, :mix_tasks},
      {:configuration, :orchestration},
      {:configuration, :runtime},
      {:configuration, :ssh},
      {:configuration, :task_support},
      {:orchestration, :mix_tasks},
      {:orchestration, :task_support},
      {:runtime, :mix_tasks},
      {:runtime, :orchestration},
      {:runtime, :task_support},
      {:ssh, :mix_tasks},
      {:ssh, :orchestration},
      {:ssh, :runtime},
      {:ssh, :task_support},
      {:task_support, :mix_tasks},
      {:task_support, :orchestration},
      {:task_support, :ssh},
      {:core, :commands},
      {:core, :configuration},
      {:core, :mix_tasks},
      {:core, :orchestration},
      {:core, :runtime},
      {:core, :ssh},
      {:core, :task_support}
    ]
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
