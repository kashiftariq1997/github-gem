# app/services/github_queries.rb
module GithubQueries
  REPOSITORIES_QUERY = <<-GRAPHQL
    query($login: String!) {
      user(login: $login) {
        repositories(first: 100) {
          nodes {
            name
            description
            url
          }
        }
      }
    }
  GRAPHQL
end
