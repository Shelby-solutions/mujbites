import React, { useEffect } from 'react';
import axios from 'axios';

const OrderAutoCancel = ({ order, onOrderUpdate }) => {
  useEffect(() => {
    let timeoutId;

    const checkAndCancelOrder = async () => {
      const orderTime = new Date(order.createdAt).getTime();
      const currentTime = new Date().getTime();
      const timeDifference = currentTime - orderTime;
      const timeoutDuration = 8 * 60 * 1000; // 8 minutes in milliseconds

      // If order is still in "Placed" status and 8 minutes have passed
      if (order.orderStatus === 'Placed' && timeDifference >= timeoutDuration) {
        try {
          const token = localStorage.getItem('userToken');
          await axios.put(
            `/api/restaurants/orders/${order._id}`,
            {
              status: 'Cancelled',
              cancellationReason: "Your chosen restaurant couldn't take your order this time, but don't worry—we have plenty of other amazing restaurants waiting to serve you. Explore your next favorite meal now!"
            },
            { headers: { Authorization: `Bearer ${token}` } }
          );
          
          if (onOrderUpdate) {
            onOrderUpdate(order._id, 'Cancelled');
          }
        } catch (error) {
          console.error('Error auto-cancelling order:', error);
        }
      } else if (order.orderStatus === 'Placed') {
        // Set timeout for remaining time until 8 minutes
        const remainingTime = timeoutDuration - timeDifference;
        if (remainingTime > 0) {
          timeoutId = setTimeout(checkAndCancelOrder, remainingTime);
        }
      }
    };

    checkAndCancelOrder();

    return () => {
      if (timeoutId) {
        clearTimeout(timeoutId);
      }
    };
  }, [order, onOrderUpdate]);

  return null; // This is a utility component that doesn't render anything
};

export default OrderAutoCancel;