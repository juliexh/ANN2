
#' @title Plot training and validation loss
#' @description \code{plot} Generate plots of the loss against epochs
#' @details A genereric function for training neural nets
#' @param x Object of class \code{ANN}
#' @param ... further arguments to be passed to plot
#' @return Plots
#' @method plot ANN
#' @export
plot.ANN <- function(x, ...) {
  
  # Obtain training history from ANN object
  train_hist <- x$Rcpp_ANN$getTrainHistory()
  
  # Make a vector x
  x_seq <- c(unlist(sapply(unique(train_hist$epoch), function(xx) {
    n <- sum(train_hist$epoch==xx) + 1
    xx + seq(from = 0, to = 1, length.out = n)[-n]
  })))
  
  # Make df, add validation loss if applicable
  df <- data.frame(x = x_seq, Training = train_hist$train_loss)
  if ( train_hist$validate ) df$Validation <- train_hist$val_loss 
  
  # Meld df
  df_melt <- reshape2::melt(df, id.vars = 'x', value.name = 'y')
  
  # Viridis colors
  viridis_cols <- viridisLite::viridis(n = 2)
  
  # Return plot
  ggplot(data = df_melt) + 
    geom_path(aes(x = x, y = y, color = variable)) + 
    labs(x = 'Epoch', y = 'Loss') + 
    scale_color_manual(name = NULL, values = c('Training' = viridis_cols[1], 
                                               'Validation' = viridis_cols[2]))
}

#' @title Reconstruction plot
#' @description 
#' \code{recPlot} plot original and reconstructed data points in a single plot 
#' with connecting lines between original value and corresponding reconstruction
#' @details Matrix plot of pairwise dimensions 
#' @param object autoencoder object of class \code{ANN} 
#' @param X data matrix with original values to be reconstructed and plotted
#' @param colors optional vector of discrete colors. The reconstruction errors
#' are are used as color if this argument is not specified
#' @return Plots
#' @export
recPlot <- function(object, X, colors = NULL) {
  
  # X as matrix and reconstuct
  X   <- as.matrix(X)
  rec <- reconstruct(object, X)
  rX  <- rec$reconstructed
  
  # Extract meta, set derived constants
  meta  <- object$Rcpp_ANN$getMeta()
  n_row <- nrow(X)
  n_col <- meta$n_in
  dim_names <- meta$y_names
  
  # Create data.frame containing points for original values and reconstructions
  # This created the matrix like structure for pairwise plotting of dimensions
  dim_combinations <- as.matrix( expand.grid(seq_len(n_col), seq_len(n_col)) )
  values  <- apply( dim_combinations, 2, function(dc)  X[,dc] )
  recs    <- apply( dim_combinations, 2, function(dc) rX[,dc] )
  dims    <- matrix( dim_names[rep(dim_combinations, each = n_row)], ncol = 2)
  df_plot <- data.frame(dims, values, recs)
  colnames(df_plot) <- c('x_dim', 'y_dim', 'x_val', 'y_val', 'x_rec', 'y_rec')
  
  # Create data.frame for x and y values seperately in order to create the 
  # data.frame for connection lines between original points and reconstructions
  df_x <- df_plot[,c('x_dim', 'y_dim', 'x_val', 'x_rec')]
  df_y <- df_plot[,c('x_dim', 'y_dim', 'y_val', 'y_rec')]
  colnames(df_x) <- colnames(df_y) <- c('x_dim', 'y_dim', 'x', 'y')
  df_x$obs <- df_y$obs <- seq_len(nrow(df_plot))
  
  # Melt data.frames and merge for connection lines
  df_lin_x <- melt(df_x, id.vars = c('obs', 'x_dim', 'y_dim'))
  df_lin_y <- melt(df_y, id.vars = c('obs', 'x_dim', 'y_dim'))
  df_lin <- merge(df_lin_x, df_lin_y, by = c('obs', 'x_dim', 'y_dim', 'variable'))
  
  if ( !is.null(colors) || !all(is.na(colors)) ) {
    df_plot$col <- colors
    gg_color <- scale_color_viridis_d(name = NULL)
  } else {
    df_plot$col <- rec$errors
    gg_color <- scale_color_viridis_c(name = 'Rec. Err.')
  }
  
  # Create and return plot
  ggplot(data = df_plot) +
    geom_point(aes(x = x_val, y = y_val), color = 'darkgrey') +
    geom_path(data = df_lin, aes(x = value.x, y = value.y, group = obs), 
              color = 'darkgrey') +
    geom_point(aes(x = x_rec, y = y_rec, color = col)) +
    facet_grid(y_dim ~ x_dim, scales = "free") + 
    labs(x = NULL, y = NULL) + 
    gg_color
}

#' @title Compression plot
#' @description 
#' \code{comprPlot} plot compressed observation in pairwise dimensions
#' @details Matrix plot of pairwise dimensions 
#' @param object autoencoder object of class \code{ANN} 
#' @param X data matrix with original values to be compressed and plotted
#' @param colors optional vector of discrete colors
#' @return Plots
#' @export
comprPlot <- function(object, X, colors = NULL) {
  
  # X as matrix and reconstuct
  X  <- as.matrix(X)
  cX <- encode(object, X)
  
  # Extract meta, set derived constants
  meta  <- object$Rcpp_ANN$getMeta()
  n_row <- nrow(X)
  n_col <- ncol(cX)
  dim_names <- colnames(cX)
  
  # Create data.frame containing points for compressed values
  # This created the matrix like structure for pairwise plotting of dimensions
  dim_combinations <- as.matrix( expand.grid(seq_len(n_col), seq_len(n_col)) )
  compr   <- apply( dim_combinations, 2, function(dc) cX[,dc] )
  dims    <- matrix( dim_names[rep(dim_combinations, each = n_row)], ncol = 2)
  df_plot <- data.frame(dims, compr)
  colnames(df_plot) <- c('x_dim', 'y_dim', 'x_compr', 'y_compr')
  
  if ( !is.null(colors) || !all(is.na(colors)) ) {
    df_plot$col <- colors
    gg_color    <- scale_color_viridis_d(name = NULL)
  } else {
    df_plot$col <- 'a'
    gg_color    <- scale_color_viridis_d(guide = FALSE)
  }
  
  # Create and return plot
  ggplot(data = df_plot) +
    geom_point(aes(x = x_compr, y = y_compr, color = col)) +
    facet_grid(y_dim ~ x_dim, scales = "free") + 
    labs(x = NULL, y = NULL) + 
    gg_color
}
