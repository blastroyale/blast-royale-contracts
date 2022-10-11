module.exports = {
  env: {
    browser: false,
    es2021: true,
    mocha: true,
    node: true
  },
  plugins: ['@typescript-eslint'],
  extends: ['standard'],
  parser: '@typescript-eslint/parser',
  parserOptions: {
    ecmaVersion: 12
  },
  rules: {
    semi: ['error', 'never'],
    indent: ['error', 2]
  }
}
