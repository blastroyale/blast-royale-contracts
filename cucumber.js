const common = [
  "features/**/*.feature",
  "--format progress-bar",
  "--publish",
  "--parallel 5",
  "--require ./dist/features/step_definitions/**/*.js",
  "--require ./dist/features/step_definitions/*.js",
  "--require ./dist/features/support/*.js",
].join(" ");

module.exports = {
  default: common,
};
