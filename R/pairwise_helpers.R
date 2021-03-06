#' @param x distance matrix, long format, dataframe; Target
#' @param y distance matrix, long format, dataframe; Query
#' @param by <character vector>; match columns between the target and query
#' @details The first and second columns must be the vectors to match in y

long_distance_matrix_join <- function(x, y, by){

  # assert that by is in both x and y

  yexpand <- y
  if(ncol(y) > 2){
    colnames(yexpand) <- colnames(y)[c(2,1,3:ncol(y))]
    } else{
    colnames(y)[c(2,1)]
    }


  yexpand <- rbind.data.frame(y, yexpand) # now have all pairwise possibilities
  yexpand <- yexpand[!duplicated(yexpand), ]
  merged <- left_join(x, yexpand, by = by)

  return(merged)

}




#' @param x distance matrix, long format, dataframe
#' @details The first and second columns must be the vectors to match in y

expand_distance_matrix <- function(x){


  xexpand <- x
  if(ncol(x) > 2){
    colnames(xexpand) <- colnames(x)[c(2,1,3:ncol(x))]
  } else{
    colnames(x)[c(2,1)]
  }


  xexpand <- rbind.data.frame(x, xexpand) # now have all pairwise possibilities

  return(xexpand)

}
