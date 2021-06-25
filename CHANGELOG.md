# CHANGELOG

This Changelog tracks major changes to the GitLab Development Kit,
such as dependency updates (those not handled by Bundler) and new
features.

## 2021-03-19

- Replace GDK master refs with main !1885
- Do foundational work to support gitlab-org/gitlab default branch !1890
- Improve our default new Merge Request template !1879

## 2021-03-12

- Promote auto_reconfigure to stable and default enabled !1873
- Run workhorse from gitlab/workhorse !1808
- Add Reviewer Roulette for the GDK project !1863
- Make jaeger no longer enabled by default !1874
- Add advanced install instructions for RHEL 8 !1852

## 2021-03-05

- New asdf.opt_out setting !1862
- Make jaeger 1.21.0 the default !1865
- Add Arch and Manjaro to supported OS list !1855

## 2021-02-26

- Add `gdk pristine` command !1811
- Enable `nakayoshi_fork` for Puma by default !1832
- Tidy up gdk commands docs !1844
- Add `gdk measure-workflow` command !1828
- Add KAS URL configuration !1842
- Add `gdk reset-data` command !1174
- Add steps to enable Rails console and toggle flags !1833

## 2018-01-11

- Added ChromeDriver to deprecate PhantomJS. !423 !380

## 2017-11-24

- Add Docker-in-Docker support in `Vagrantfile` (needed to run GitLab Container Registry)

## 2017-11-21

- [GitLab Geo] Add replication slot

## 2017-02-01

- Add webpack process to `Procfile` configure it within `gitlab.yml` !237
  Make sure to [update GDK](doc/update-gdk.md) and read the
  [troubleshooting section](doc/howto/troubleshooting.md#webpack).

## 2016-10-31

- Add root check to catch root move problems. Requires gem 0.2.3 or
  newer. Next time you run `git pull` in the `gitlab-development-kit`
  root directory, also run `gem install gitlab-development-kit` to
  upgrade the gem.

## 2016-09-09

- Update `Procfile` for `gitlab_workhorse_secret`

## 2016-09-05

- Added a Changelog.

## 2016-08-16

- Updated PhantomJS to 2.1.1. !182

## 2016-08-11

- Updated Ruby to 2.3.1. !178

## 2016-08-08

- Added the [`gitlab-development-kit` gem](https://rubygems.org/gems/gitlab-development-kit), commands can now be run using the `gdk` CLI. !174
- Began using a `GOPATH` for GitLab Workhorse, this change requires manual intervention. [See the update instructions here](https://gitlab.com/gitlab-org/gitlab-development-kit/blob/fd04b7f1a3a72302af71c1a7923daaa5b22dcd28/gitlab-workhorse/README.md#cleaning-up-an-old-gitlab-workhorse-checkout). !173
