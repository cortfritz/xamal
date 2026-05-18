[
  layers: [
    cli: "Xamal.CLI.*",
    commands: "Xamal.Commands.*",
    configuration: "Xamal.Configuration.*",
    ssh: "Xamal.SSH.*"
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
