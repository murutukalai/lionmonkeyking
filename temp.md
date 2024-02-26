```
a-start:a-clean db-dev
  cd apps/db && sqlx database reset --source dev -y
  cd apps/frontend && yarn install && yarn build && yarn copy
  cd apps/backend && cargo dev

a-clean:
  cd apps/frontend && yarn cache clean
```
